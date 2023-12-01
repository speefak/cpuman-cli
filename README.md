# cpuman-cli
manage cpu cores and powerstatus of cpu ( ncurses )

    Usage: cpuman-cli_v2.1.sh <options> 
     -ss <0.1-999>		=> show cpu specifications ( <seconds> for loop output )
     -[e|d]c <1,2-3,4>	=> (e)nable (d)isable core 
     -[e|d]p <1,4-5,8>	=> (e)nable (d)isable cpu 
     -[e|d]h 		=> (e)nable (d)isable hyperthreading 
     -[e|d]a 		=> (e)nable (d)isable all CPUs and hyperthreading
     -tc <temp threshold>	=> cpu (t)emperature (c)heck ( send mail if threashold temp reached ) 
     -h			=> help dialog 
     -m			=> monochrome output 
     -i			=> show script information 
     -cfrp			=> check for required packets 
     -cpi			=> use cpuinfo output for freqenucy calculating
     


<div align="center">
 <img src="https://raw.githubusercontent.com/speefak/cpuman-cli/main/cpuman-cli_screenshot_v2.7.png"  style="text-align:center" >
</div>
