\ simple text editor

256 constant line-size
4096 constant max-lines
create lines max-lines line-size * allot
0 value row 0 value col
0 value vx
1 value nlines
0 lines c!
0 value scroll
80 constant w
24 constant h
255 constant buf-size
create buf buf-size allot
256 constant filename-size
create filename filename-size allot
0 filename c!
0 value unsaved

: line ( n -- addr )
  line-size * lines + ;

: insert-char ( c -- )
  row line
  dup c@ 1+ 2dup swap c!
  swap 1+ swap
  col 1+ swap do
    dup i +
    dup 1- c@ swap c!
  -1 +loop
  col + c!
  col 1+ to col
  col to vx ;

: line-copy ( n1 n2 -- )
  line swap line swap
  line-size 0 do
    over c@ over c!
    1+ swap 1+ swap
  loop
  2drop ;

: insert-line ( -- )
  row 1+ nlines do
    i 1- i line-copy
  -1 +loop
  0 row 1+ line c!
  nlines 1+ to nlines ;

: newline ( -- )
  insert-line
  row line dup
  dup c@ col -
  dup 0= if
    2drop
    row 1+ to row
    0 to col
    0 to vx
    exit
  then
  over col swap c!
  swap line-size + 2dup c! ( -- addr1 len addr2 )
  swap 0 do
    over 1+ col + i + c@
    over 1+ i + c!
  loop
  2drop
  row 1+ to row
  0 to col 
  0 to vx ;

: insert ( addr n -- )
  dup 0= if 2drop exit then
  0 do
    dup c@ insert-char
    1+
  loop
  drop ;

: print-file ( -- )
  lines
  nlines 0 do
    dup 1+ over c@ type
    [char] \ emit [char] n emit cr
    line-size +
  loop
  drop
  s" [eof]" type cr ;

: bind-cursor ( -- )
  vx to col
  row line c@ dup vx <= if
    1- to col
  else drop then ;

: up ( -- )
  row if
    row 1- to row
    bind-cursor
  then ;

: down ( -- )
  row nlines 1- < if
    row 1+ to row bind-cursor
  then ;

: left ( -- )
  col to vx
  vx if vx 1- to vx then bind-cursor ;

: right ( -- )
  col to vx
  vx row line c@ 1- < if vx 1+ to vx then bind-cursor ;

: delete ( -- )
  row line
  dup c@
  dup 0= if
    2drop exit
  then
  -1 to unsaved
  col 1+ > if
    dup c@ 1- col do
      dup 1+ i +
      dup 1+ c@ swap c!
    loop
  then
  dup c@ 1- swap c!
  bind-cursor ;

: redraw ( -- )
  page
  scroll
  h 1- nlines scroll - min 0 do
    dup i + line dup
    dup 1+ swap c@
    type cr
    c@ w / 1+
  +loop
  drop ;

: place-cursor ( -- )
  scroll
  h 1- nlines scroll - min 0 do
    dup i + dup line
    swap row = if
      0 i at-xy
      1+ col type
      drop unloop exit
    then
    c@ w / 1+
  +loop
  drop
  row scroll < if
    row to scroll
  else
    scroll 1+ to scroll
  then
  redraw recurse ;

: redraw redraw place-cursor ;

: print-end ( -- )
  row line
  dup c@ col -
  swap 1+ col +
  over type
  32 dup emit emit
  -2 do
    8 emit
  loop ;

: do-insert ( -- )
  buf
  begin
    key
    dup 13 = if
      drop
      buf - buf swap insert newline
      redraw
      buf
    else dup 127 = if
      drop
      8 emit print-end
      dup buf <> if 1- then
    else dup 27 = if
      drop
      dup buf <> if
        -1 to unsaved
      then
      buf - buf swap insert
      left
      place-cursor
      exit
    else
      dup emit print-end
      over c! 1+
    then then then
  again ;

: strchr ( str len c -- str len )
  >r dup -rot r> -rot
  0 do
    2dup c@ = if
      nip swap i -
      unloop exit
    then
    1+
  loop
  2drop drop 0 0 ;

: split-str ( str len -- str len str len )
  2dup 32 strchr
  2swap 2 pick - ;

: at-bottom ( -- )
  0 h 1- 2dup at-xy
  w 0 do 32 emit loop
  at-xy ;

: get-command ( -- argstr len cmdstr len )
  at-bottom
  [char] : emit
  buf w 1- accept
  buf swap
  split-str ;

: filename-str ( -- str len )
  filename dup 1+ swap c@ ;

: w-file ( -- ior )
  filename-str
  w/o create-file if
    2drop -1 exit
  then
  nlines 0 do
    dup
    i line dup 1+ swap c@
    rot write-line drop
  loop
  close-file drop 0 ;

: o-file ( -- ior )
  filename-str
  r/o open-file if
    2drop -1 exit
  then
  0 to nlines
  0 to col
  begin
    dup buf 1
    rot read-file drop 0=
    buf c@
    dup 10 = if
      drop
      col nlines line c!
      nlines 1+ to nlines
      0 to col
    else
      nlines line col + 1+ c!
      col 1+ to col
    then
  until
  close-file drop
  col nlines line c!
  nlines 1+ to nlines
  0 to col
  0 to row
  0 to vx
  redraw 0 ;

: set-filename ( str len -- )
  dup if
    dup filename c!
    0 do
      dup i + c@
      filename i + c!
    loop
    drop
  else
    2drop
  then ;

: try-open ( str len -- )
  at-bottom
  dup 0= if
    2drop
    ." no filename specified for opening"
    exit
  then
  set-filename
  o-file if
    ." failed to open "
    filename-str type
    exit
  then
  at-bottom
  ." opened "
  filename-str type
  ."  reading " nlines . ." lines"
  place-cursor ;

: check-save ( -- )
  unsaved if
    2drop 2drop
    at-bottom
    ." file not saved, use ! to confirm"
    place-cursor
    r> drop exit
  then ;

: command ( -- )
  get-command
  2dup s" q" str= if
    check-save
    2drop 2drop
    at-bottom bye
    exit
  then
  2dup s" q!" str= if
    2drop 2drop
    at-bottom bye
  then
  2dup s" w" str= if
    check-save
    2drop set-filename
    at-bottom
    filename c@ 0= if
      ." no filename specified for writing"
    else w-file if
      ." failed to save "
      filename dup 1+ swap c@ type
    else
      ." wrote " nlines .
      ." lines to "
      filename dup 1+ swap c@ type
      0 to unsaved
    then then
    place-cursor
    exit
  then
  2dup s" o" str= if
    check-save
    2drop try-open
    exit
  then
  2dup s" o!" str= if
    2drop try-open
    exit
  then
  at-bottom
  ." unknown command "
  2dup type
  place-cursor
  2drop 2drop ;

: when ( -- )
  dup char = if
    drop ' execute
    >r exit
  then ; immediate

: control ( -- )
  dup [char] h = if
    drop left exit
  then
  dup [char] l = if
    drop right exit
  then
  dup [char] k = if
    drop up exit
  then
  dup [char] j = if
    drop down exit
  then
  dup [char] i = if
    drop do-insert exit
  then
  dup [char] a = if
    drop
    col 1+ to col
    col to vx
    place-cursor
    do-insert
    exit
  then
  dup [char] I = if
    drop
    0 to col place-cursor
    do-insert
    exit
  then
  dup [char] A = if
    drop
    row line c@ to col
    col to vx
    place-cursor
    do-insert
    exit
  then
  dup [char] x = if
    drop
    delete 8 emit print-end
    exit
  then
  dup [char] X = if
    drop
    col if
      col 1- to col
      col to vx
      delete 8 emit print-end
    then
    exit
  then
  dup [char] : = if
    drop command exit
  then ;

: main-loop ( -- )
  redraw
  begin
    key control
    place-cursor
  again ;

s" Hello, world" insert
s" !" insert
col 6 - to col
newline
s" there, " insert
\ print-file
\ redraw do-insert redraw key bye
main-loop
