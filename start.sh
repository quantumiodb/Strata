#!/bin/bash
# Strata 启动脚本：./start.sh [start|stop|status|restart]
# 引擎是本机用 CUDA 12.2 编译的 engine/strata（驱动 535），配置 strata-iq2_xs.json
cd "$(dirname "$0")" || exit 1
PORT=8080
HEALTH="http://127.0.0.1:$PORT/health"

status() {
  local h; h=$(curl -s -m 3 "$HEALTH")
  if [ -n "$h" ]; then echo "$h"; else echo "Strata 未运行"; return 1; fi
}

stop() {
  pkill -f '[s]erve/server.py'; pkill -f '[e]ngine/strata'
  for i in $(seq 1 20); do pgrep -f '[s]erve/server.py|[e]ngine/strata' >/dev/null || break; sleep 1; done
  echo "Strata 已停止"
}

start() {
  if curl -s -m 3 "$HEALTH" | grep -q '"loaded": true'; then echo "Strata 已在运行"; status; return 0; fi
  pgrep -f '[s]erve/server.py' >/dev/null && stop
  env -u PYTHONPATH nohup ./run-iq2_xs.sh > strata-server.out 2>&1 &
  echo "正在启动 Strata（模型加载约 1 到 3 分钟，期间机器可能卡顿）..."
  for i in $(seq 1 120); do
    sleep 3
    if curl -s -m 3 "$HEALTH" | grep -q '"loaded": true'; then
      echo "就绪: http://127.0.0.1:$PORT  (OpenAI: /v1, Anthropic: /v1/messages)"
      grep -E 'VRAM free with everything' strata-iq2_xs.log | tail -1
      return 0
    fi
    if ! pgrep -f '[s]erve/server.py' >/dev/null; then
      echo "启动失败，最后几行日志:"; tail -5 strata-server.out; tail -3 strata-iq2_xs.log; return 1
    fi
  done
  echo "等待超时，查看 strata-server.out 和 strata-iq2_xs.log"; return 1
}

case "${1:-start}" in
  start) start ;;
  stop) stop ;;
  status) status ;;
  restart) stop; start ;;
  *) echo "用法: $0 [start|stop|status|restart]"; exit 2 ;;
esac
