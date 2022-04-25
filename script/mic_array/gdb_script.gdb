set confirm off
set width -1
set height -1
connect  --xscope-port-blocking --xscope-port localhost:10234
load
    if ($xcore_boot != 0)
      detach
    else
      continue

    end