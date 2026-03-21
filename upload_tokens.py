"""
批量投递认证文件到 CLIProxyAPI
用法: python upload_tokens.py [选项]

示例:
  python upload_tokens.py                          # 使用默认配置投递
  python upload_tokens.py --host 192.168.1.100     # 指定服务器地址
  python upload_tokens.py --dry-run                # 仅预览，不实际上传
  python upload_tokens.py --workers 20             # 20 并发上传
"""

import os
import sys
import json
import time
import argparse
import requests
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed

# ── 默认配置 ──
DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 8317
DEFAULT_KEY = "your-management-key"
DEFAULT_TOKEN_DIR = "./tokens"
DEFAULT_WORKERS = 10


def upload_file(session: requests.Session, url: str, headers: dict, filepath: Path) -> dict:
    """上传单个认证文件（multipart 方式）"""
    try:
        with open(filepath, "rb") as f:
            files = {"file": (filepath.name, f, "application/json")}
            resp = session.post(url, headers=headers, files=files, timeout=30)
        return {
            "file": filepath.name,
            "status": resp.status_code,
            "body": resp.json() if resp.headers.get("content-type", "").startswith("application/json") else resp.text,
            "ok": resp.status_code == 200,
        }
    except Exception as e:
        return {"file": filepath.name, "status": -1, "body": str(e), "ok": False}


def main():
    parser = argparse.ArgumentParser(description="批量投递认证文件到 CLIProxyAPI")
    parser.add_argument("--host", default=DEFAULT_HOST, help=f"服务器地址 (默认: {DEFAULT_HOST})")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help=f"端口 (默认: {DEFAULT_PORT})")
    parser.add_argument("--key", default=DEFAULT_KEY, help="Management API 密钥")
    parser.add_argument("--token-dir", default=DEFAULT_TOKEN_DIR, help=f"认证文件目录 (默认: {DEFAULT_TOKEN_DIR})")
    parser.add_argument("--workers", type=int, default=DEFAULT_WORKERS, help=f"并发数 (默认: {DEFAULT_WORKERS})")
    parser.add_argument("--dry-run", action="store_true", help="仅预览文件列表，不实际上传")
    parser.add_argument("--https", action="store_true", help="使用 HTTPS")
    args = parser.parse_args()

    token_dir = Path(args.token_dir)
    if not token_dir.is_dir():
        print(f"[错误] 目录不存在: {token_dir}")
        sys.exit(1)

    files = sorted(token_dir.glob("*.json"))
    if not files:
        print(f"[错误] 目录下没有 .json 文件: {token_dir}")
        sys.exit(1)

    print(f"找到 {len(files)} 个认证文件")

    if args.dry_run:
        for f in files[:10]:
            print(f"  {f.name}")
        if len(files) > 10:
            print(f"  ... 还有 {len(files) - 10} 个文件")
        print("\n[dry-run] 未执行上传")
        return

    scheme = "https" if args.https else "http"
    base_url = f"{scheme}://{args.host}:{args.port}"
    upload_url = f"{base_url}/v0/management/auth-files"
    headers = {"Authorization": f"Bearer {args.key}"}

    # 先测试连通性
    print(f"目标: {upload_url}")
    try:
        test_resp = requests.get(
            f"{base_url}/v0/management/auth-files",
            headers=headers,
            timeout=10,
        )
        print(f"连通性测试: HTTP {test_resp.status_code}")
        if test_resp.status_code == 401:
            print("[错误] Management 密钥无效")
            sys.exit(1)
        if test_resp.status_code == 404:
            print("[错误] Management API 未启用")
            sys.exit(1)
    except requests.ConnectionError:
        print(f"[错误] 无法连接到 {base_url}，请确认服务已启动")
        sys.exit(1)

    # 并发上传
    success = 0
    failed = 0
    errors = []
    start = time.time()

    session = requests.Session()
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = {pool.submit(upload_file, session, upload_url, headers, f): f for f in files}
        for i, future in enumerate(as_completed(futures), 1):
            result = future.result()
            if result["ok"]:
                success += 1
                tag = "OK"
            else:
                failed += 1
                errors.append(result)
                tag = f"FAIL({result['status']})"
            # 进度输出
            print(f"\r[{i}/{len(files)}] {tag} {result['file']}", end="", flush=True)

    elapsed = time.time() - start
    print(f"\n\n{'='*50}")
    print(f"完成! 耗时 {elapsed:.1f}s")
    print(f"成功: {success}  失败: {failed}  总计: {len(files)}")

    if errors:
        print(f"\n失败详情 (前10条):")
        for e in errors[:10]:
            print(f"  {e['file']}: [{e['status']}] {e['body']}")


if __name__ == "__main__":
    main()
