import json,time,urllib.request,sys,statistics
URL="http://127.0.0.1:8080/v1/chat/completions"
P=[("en","Write a 400-word short story about a lighthouse keeper who finds a message in a bottle."),
   ("zh","用中文写一篇 600 字左右的短文，主题是“我的家乡的四季”。"),
   ("code","Write a Python class implementing an LRU cache with get/put, plus a small test suite using unittest. Include docstrings."),
   ("zhcode","用 Python 实现一个简单的命令行待办事项程序，支持添加、删除、列出，用中文注释说明每个函数。")]
tag=sys.argv[1] if len(sys.argv)>1 else "run"; runs=int(sys.argv[2]) if len(sys.argv)>2 else 2
extra=json.loads(sys.argv[3]) if len(sys.argv)>3 else {}
res=[]
for r in range(runs):
  for name,c in P:
    body={"model":"strata","messages":[{"role":"user","content":c}],"max_tokens":384,"reasoning_effort":"none"}; body.update(extra)
    t=time.time(); o=json.load(urllib.request.urlopen(urllib.request.Request(URL,json.dumps(body).encode(),{"Content-Type":"application/json","Authorization":"Bearer "+open(__import__("os").path.expanduser("~/.config/strata/api_key")).read().strip()}),timeout=600)); w=time.time()-t
    tm=o["timings"]; res.append((name,tm["predicted_n"],tm["predicted_per_second"],tm.get("draft_n_accepted",0),tm.get("draft_n",0)))
    print(f"{tag} {name:6} gen={tm['predicted_n']:4} tok/s={tm['predicted_per_second']:6.1f} draft={tm.get('draft_n_accepted',0)}/{tm.get('draft_n',0)} wall={w:5.1f}",flush=True)
tot_tok=sum(x[1] for x in res); tot_s=sum(x[1]/x[2] for x in res)
print(f"{tag} SUMMARY tokens={tot_tok} aggregate tok/s={tot_tok/tot_s:.1f} median={statistics.median(x[2] for x in res):.1f}")
