#!/bin/bash
# Strata 启动脚本：./start.sh [start|stop|status|restart]
# 引擎是本机用 CUDA 12.2 编译的 engine/strata（驱动 535），配置 strata-iq2_xs.json
cd "$(dirname "$0")" || exit 1
MODEL="${STRATA_MODEL:-iq2_xs}"   # 哪个模型：STRATA_MODEL=q2_0 ./start.sh start
PORT=8080
HEALTH="http://127.0.0.1:$PORT/health"
# 进程匹配锚定到真实命令行开头，避免 pkill -f 误杀命令行里恰好含有这些路径的其他 shell
SRV="$PWD/.venv/bin/python $PWD/serve/server.py"
ENG="$PWD/engine/strata "

status() {
  local h; h=$(curl -s -m 3 "$HEALTH")
  if [ -n "$h" ]; then echo "$h"; else echo "Strata 未运行"; return 1; fi
}

stop() {
  # SIGTERM 给 server 即可：它会向引擎发 QUIT，引擎自己释放锁定内存并保存学习到的专家画像；超时才强杀
  pkill -f "^$SRV"
  for i in $(seq 1 60); do pgrep -f "^$SRV|^$ENG" >/dev/null || break; sleep 1; done
  pgrep -f "^$ENG" >/dev/null && { echo "引擎 60 秒内未退出，强制结束"; pkill -9 -f "^$ENG"; }
  echo "Strata 已停止"
}

start() {
  if curl -s -m 3 "$HEALTH" | grep -q '"loaded": true'; then echo "Strata 已在运行"; status; return 0; fi
  pgrep -f "^$SRV" >/dev/null && stop
  # 启动前把模型文件逐出页缓存：引擎的 34 GB 专家内存用透明大页，连续空闲内存越多覆盖率越高（实测 25 -> 29 GB）
  python3 - <<'PY' 2>/dev/null
import os,glob
for f in glob.glob(os.path.expanduser('~/workspace/Strata-data/**/*'),recursive=True):
    if os.path.isfile(f):
        try: fd=os.open(f,os.O_RDONLY); os.posix_fadvise(fd,0,0,os.POSIX_FADV_DONTNEED); os.close(fd)
        except Exception: pass
PY
  env -u PYTHONPATH nohup "./run-$MODEL.sh" > strata-server.out 2>&1 &
  echo "正在启动 Strata（模型加载约 1 到 3 分钟，期间机器可能卡顿）..."
  for i in $(seq 1 120); do
    sleep 3
    if curl -s -m 3 "$HEALTH" | grep -q '"loaded": true'; then
      echo "就绪: http://127.0.0.1:$PORT  (OpenAI: /v1, Anthropic: /v1/messages)"
      grep -E 'VRAM free with everything' "strata-$MODEL.log" | tail -1
      return 0
    fi
    if ! pgrep -f "^$SRV" >/dev/null; then
      echo "启动失败，最后几行日志:"; tail -5 strata-server.out; tail -3 "strata-$MODEL.log"; return 1
    fi
  done
  echo "等待超时，查看 strata-server.out 和 "strata-$MODEL.log""; return 1
}

case "${1:-start}" in
  start) start ;;
  stop) stop ;;
  status) status ;;
  restart) stop; start ;;
  *) echo "用法: $0 [start|stop|status|restart]"; exit 2 ;;
esac
