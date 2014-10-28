#!/bin/bash
# Adapted from:
# https://evilzone.org/scripting-languages/%28bash%29-nyan-cat-animation-2061/

# config
IMGS=(
"
 +      o     +              o    \n\
     +             o     +       +\n\
 o          +                     \n\
     o  +           +        +    \n\
 +        o     o       +        o\n\
 -_-_-_-_-_-_-_,------,      o    \n\
 _-_-_-_-_-_-_-|   /\_/\          \n\
 -_-_-_-_-_-_-~|__( ^ .^)  +     +\n\
 _-_-_-_-_-_-_-\"\"  \"\"         \n\
 +      o         o   +       o   \n\
     +         +                  \n\
 o        o         o      o     +\n\
     o           +                \n\
 +      +     o        o      +   \n
" "
     o  +           +        +    \n\
 o          +                    o\n\
     o                 +          \n\
 +      o     +              o    \n\
  o     +        o               +\n\
 _-_-_-_-_-_-_-,------,  o      + \n\
 -_-_-_-_-_-_-_|   /\_/\    +     \n\
 _-_-_-_-_-_-_~|__( ^ .^)     o   \n\
 -_-_-_-_-_-_-_  \"\"  \"\"       \n\
 +      +     o        o      +   \n\
 o        +                o     +\n\
 +      o         +     +       o \n\
     +         +                  \n\
        +           o        +    \n
" )
REFRESH="0.5"
# end

# count lines of first ascii picture in array
LINES_PER_IMG=$(( $(echo $IMGS[0] | sed 's/\\n/\n/g' | wc -l) + 1 ))

# tput $1 LINES_PER_IMG times, used for cuu1(cursor up) cud1(cursor down)
tput_loop() { for((x=0; x < $LINES_PER_IMG; x++)); do tput $1; done; }

# ^C abort, script cleanup
trap sigtrap INT
sigtrap() {
  # make cursor visible again
  tput cvvis

  # reset cursor
  tput_loop "cud1"

  echo "caught signal SIGINT(CTRL+C), quitting ..."
  exit 1
}

# need multi-space strings
IFS='%'

# hide the cursor
tput civis

# main loop, pretty self explanatory
while [ "$(ps a | awk '{print $1}' | grep $1)" ]; do for x in "${IMGS[@]}"; do
    echo -ne $x
    tput_loop "cuu1"
    sleep $REFRESH
done; done
sigtrap

# will never reach here, CTRL+C is required to quit