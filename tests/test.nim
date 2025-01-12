import pg, asyncdispatch, strutils, threadpool, std/cpuinfo

proc main1() =
  # sync version
  let pg = open("", "", "", "host=localhost port=5432 dbname=test")
  let rows = waitFor pg.rows(sql"SELECT ?, pg_sleep(1), 'hi there';", @[$1])
  echo rows

proc main2() {.async.} =
  # run 20 queries at once on a 2 connecton pool
  let pool = newAsyncPool("", "", "", "host=localhost port=5432 dbname=test", 2)
  var futures = newSeq[Future[seq[Row]]]()
  for i in 0..<20:
    futures.add pool.rows(sql"SELECT ?, pg_sleep(0.5);", @[$i])
  for f in futures:
    var res = await f
    echo res


proc mutliThreadedTest() = 
  let ncores = countProcessors()
  let nconns = if ncores == 0: 2 else: ncores
  let pool = newAsyncPool("", "", "", "host=localhost port=5432 dbname=test", nconns)

  proc thread(pool: AsyncPool): seq[Row] = 
    let res = waitFor pool.rows(sql"SELECT ?, pg_sleep(0.5);", @[$getThreadId()])
    echo res

  for _ in 0..<20:
    discard spawn thread(pool) 
  sync()


proc errors() =
  # sync version
  let pg = open("", "", "", "host=localhost port=5432 dbname=test")
  block:
    echo "valid query returns 1 result"
    let rows = waitFor pg.rows(sql"select 1;", @[])
    echo rows
  block:
    echo "valid query retirms 0 results"
    let rows = waitFor pg.rows(sql"select 1 limit 0;", @[])
    echo rows
  block:
    echo "invalid query"
    var rows = newSeq[Row]()
    try:
      rows = waitFor pg.rows(sql"invalid sql;", @[])
    except PGError:
      echo $(getCurrentExceptionMsg()).split("\n")[0]
    echo rows
  block:
    echo "invalid table"
    var rows = newSeq[Row]()
    try:
      rows = waitFor pg.rows(sql"select * from invalid_table;", @[])
    except PGError:
      echo $(getCurrentExceptionMsg()).split("\n")[0]
    echo rows


errors()
main1()
waitFor main2()
mutliThreadedTest()