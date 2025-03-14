# NOTE: This 'awk' program was written to work with BusyBox awk. It might work differently with GAWK.
#       It was written by someone who is very bad at 'awk'.
#
# This 'awk' program exists to do most of the changing of 'terraform output' output to JSON. It wraps
# keys in double-quotes, changes " = " to ": ", appends "," to each line, and also converts input of the form
# key = tolist([
#  "var 1",
#  "var 2",
#  "var N",
#])'
# to
# "key": [ "var 1", "var 2", "var N" ],
#
# It is to be used with a program that removes the trailing "," from its last line of output, and then wraps the output in "{ }"

BEGIN { in_tolist = 0; acc = ""; key = ""}

# start of tolist list
/ = tolist\(\[/ {
  in_tolist = 1
  key = $1
  next
}
# end of tolist list
/^\]\)$/ { 
  in_tolist = 0
  gsub(/ /, ", ", acc)
  print "\"" key "\": [" acc "]," ; acc = ""
  next
}
in_tolist == 1 && acc == "" { gsub(/,/, "", $1); acc = $1; next }
in_tolist == 1 { gsub(/,/, "", $1); acc = acc " " $1; next }
in_tolist == 0 { pvs = FS; FS = "="; print "\"" $1 "\": " $3 ","; FS = pvs }
