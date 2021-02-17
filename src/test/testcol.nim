import colorize

echo "Hello, I am a blue text.".fgBlue
echo "Hello, I am now also bold!".bold.fgBlue


stdout.writeLine("ciao".fgBlue, " mondo")
let
 a = "A".fgGreen
 c = "C".fgRed
 g = "G".fgBlue
 t = "T".fgYellow
 str = a & c & t & g & g & t & a
 
stdout.writeLine(str)
