-- Run only with the disposable fixture focused; restores its baseline on success.
with timeout of 15 seconds
 tell application id "com.jpwinans.size-up"
  try
  set results to {}
  repeat with commandAction in {Left, Right, Up, Down, Upper Left, Upper Right, Lower Left, Lower Right, Full Screen, Center, Prev Monitor, Next Monitor, Move Left, Move Right, Move Up, Move Down, Move Upper Left, Move Upper Right, Move Lower Left, Move Lower Right, Move Center, Third Left, Third Center, Third Right, Third Upper, Third Middle, Third Lower}
   set end of results to do action commandAction
  end repeat
  set end of results to send to monitor 1
  set end of results to move to {100, 150}
  set resizedFrame to resize to {800, 600}
  if item 3 of resizedFrame is not 800 or item 4 of resizedFrame is not 600 then error "Point argument dimensions were decoded incorrectly."
  set end of results to resizedFrame
  set rectangleFrame to move and resize to {200, 200, 900, 700}
  if item 3 of rectangleFrame is not 900 or item 4 of rectangleFrame is not 700 then error "Rectangle argument dimensions were decoded incorrectly."
  set end of results to rectangleFrame
  set end of results to fit to grid {1, 1, 2, 2} grid size {6, 6}
  set tileFrames to tile windows
  if (count of tileFrames) is not 1 or (count of item 1 of tileFrames) is not 4 then error "Tile did not return the fixture rectangle."
  set end of results to tileFrames
  set cascadeFrames to cascade windows
  if (count of cascadeFrames) is not 1 or (count of item 1 of cascadeFrames) is not 4 then error "Cascade did not return the fixture rectangle."
  set end of results to cascadeFrames
  set end of results to do action SnapBack
  return results
  on error messageText number errorCode
   try
    do action SnapBack
   end try
   error messageText number errorCode
  end try
 end tell
end timeout
