# cpuman-cli
manage cpu cores and powerstatus of cpu ( ncurses )

    Usage: cpuman-cli_v3.6.sh <options> 
    -ss <1-999|cpu>	      => (s)how cpu (s)pecifications ( <seconds> for loop output | cpu summary )
    -[e|d]c <1,2-3,4>   => (e)nable (d)isable core 
    -[e|d]p <1,4-5,8>   => (e)nable (d)isable processor 
    -[e|d]h 		=> (e)nable (d)isable hyperthreading 
    -[e|d]a 		=> (e)nable (d)isable all CPUs and hyperthreading
    -tc <temp threshold>	=> cpu (t)emperature (c)heck ( send mail if threashold temp reached ) 
    -sr <cores> <interval>	=> (s)how (c)pu core MHZ ranking 
    -col 			=> (c)olumn output for core MHZ ranking 
    -h			=> help dialog 
    -m			=> monochrome output 
    -i			=> show script information 
    -cfrp			=> check for required packets      


<div align="center">
 <img src="https://raw.githubusercontent.com/speefak/cpuman-cli/main/cpuman-cli_screenshot_v2.7.png"  style="text-align:center" >
</div>
