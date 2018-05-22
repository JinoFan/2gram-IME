#语料LM.Dic,py.txt,hzfreq.txt,train
use Encode;
use utf8;

Main();

sub Main{
	$g_MaxBiNum=1000000;
	BiCount("train");
	MergeBi(\@BiTmp,"bi.txt");
	foreach (@BiTmp){
		unlink($_);#在perl中用 unlink 操作符删除文件
	}
	InitCorpus("LM.Dic","PINYIN.txt");#原始材料为LM.Dic提取只有汉语不带拼音的词典
	LoadNgram("bi.txt","log1.txt","log2.txt");
	InitNGram("log1.txt","log2.txt");
	InitDict("hzfreq.txt","py.txt","invert.txt");
	InitPY2HZ("invert.txt");
	while (1){
		@Pys=();
		print "pls input(q to quit)\n";
		$Inp=<stdin>;
		chomp($Inp);
		if ( $Inp eq "q" ){
			last;
		}
		$IMEResult=IME($Inp);
		print "$IMEResult\n";
	}
}

sub IME{
	my($Inp)=@_;
	my @Lattice=();
	my $Result;
	Buildlattice($Inp,\@Lattice);
	Search(\@Lattice);
	$Result=Backward(\@Lattice);
	return $Result;
}
sub BiCount{
	my($File)=@_;
	$BiFile="tmp";
	open(In,"$File");
	$ZiNum=0;
	$ID=0;
	@BiTmp=();
	while(<In>){
		chomp;	
		s/\s+//g;#替换
		$Line=$_;
		while( $Line ne "" ){
			$Len=1;
			if ( ord($Line) & 0x80 ){##汉字的8位二进制码的第一位肯定是1，而0x80的二进制是10000000。
				$Len=2;
			}
			$H2=substr($Line,0,$Len);
			if ( $H1 ne  "" ){
				$Bi=$H1."_".$H2;
				$hashBi{$Bi}++;#二元组
			}
			$H1=$H2;
			$ZiNum++;
			if ( $ZiNum > $g_MaxBiNum ){#处理完的字数超过1000000时写入文件
				$BiFileTmp=$BiFile."_".$ID;
				push(@BiTmp,$BiFileTmp);
				open(Out,">$BiFileTmp");
				print "$BiFileTmp done!\n";
				foreach (sort keys %hashBi ){
					print Out "$_\t$hashBi{$_}\n";
				}
				%hashBi=();
				$ZiNum=0;
				close(Out);
				$ID++;
			}
			$Line=substr($Line,$Len,length($Line)-$Len);
		}
	}
		
	close(In);
}

sub MergeBi{
	my($RefBiFileList,$Merged)=@_;
	open(Out,">$Merged");
	
	foreach (@{$RefBiFileList}){
		my $H="F".$_;
		open($H,"$_");
		if ( <$H>=~/(\S+)\t(\d+)/ ){#读一行，并把文件指针向后移动一行
			${$hash{$1}}{$H}=$2;		
		}
	}
	@BiStr=sort keys %hash;
	while( @BiStr > 0 ){
		$Num=0;
		@Fhandle=();
		foreach $Handle(keys %{$hash{$BiStr[0]}} ){#统计二元组在每个文件中出现次数的总和
			$Num+=${$hash{$BiStr[0]}}{$Handle};
			push(@Fhandle,$Handle);
		}
		print Out "$BiStr[0]\t$Num\n";
		delete $hash{$BiStr[0]};#删除已统计的二元组
		foreach $Handle(@Fhandle){
			if ( <$Handle>=~/(\S+)\t(\d+)/ ){ #读一行，并把文件指针向后移动一行
				${$hash{$1}}{$Handle}=$2;		
			}
		}
		
		@BiStr=sort keys %hash;
	}
	
	foreach (@{$RefBiFileList}){
		my $H="F".$_;
		close($H);
	}
}
sub InitCorpus{
	my($Inp,$Outp)=@_;
	open(In,"$Inp");
	open(Out,">$Outp");
	while(<In>){
		chomp;
		if($_=~/^(\S+) (.+)$/){
			$Hzs=$1;
			$PYs=$2;
			$PYs=~s/\d//g;#将数字替换仅保留拼音
			${$hash{$PYs}}{$Hzs}=0;
		}
	}
	foreach $QuanPin(sort keys %hash){
		print Out "$QuanPin\n";
	}
	close(In);
	close(Out);
}
sub LoadNgram{
	my($Inp,$Outp1,$Outp2)=@_;
	open (A,"$Inp");
	open (Out1,">$Outp1");
	open (Out2,">$Outp2");
	while(<A>){
		chomp;
		$UTF8=decode("gbk",$_);
		@HZs=$UTF8=~/(.)\_(.)\s+(\d+)/g;
		$w1{$1}=$w1{$1}+$3;
		$w1{$2}=$w1{$2}+$3;
		$w=$w+2*$3;
		$w2{$1}{$2}=$3;
	}
	foreach (sort keys %w1 ){
		$a=log($w1{$_}/$w);
		$hz=encode("gbk",$_);
		print Out1 "$hz\t$a\n";
	}
	foreach $ele (sort keys %w2 ){
		foreach (sort keys %{$w2{$ele}} ){
			$a=log($w2{$ele}{$_}/$w1{$ele});
			$hz1=encode("gbk",$ele);
			$hz2=encode("gbk",$_);
			print Out2 "$hz1\_$hz2\t$a\n";
		}
	}
	close(A);
}
sub InitNGram{
	my($Unigram,$Bigram)=@_;
	open(A,"$Unigram");
	while(<A>){
		chomp;
		$UTF8=decode("gbk",$_);
		if($UTF8=~/(.)\s+(\S+)/g){
			$str=encode("gbk",$1);
			$HashUni{$str}=$2;
		}
	}
	close(A);
	open(B,"$Bigram");
	while(<B>){
		chomp;
		$UTF8=decode("gbk",$_);
		if($UTF8=~/(.)\_(.)\s+(\S+)/){
			$str1=encode("gbk",$1);
			$str2=encode("gbk",$2);
			${$hashBi{$str1}}{$str2}=$3;
			
		}
	}
	close(B);
}
sub InitDict{
	my($Inp1,$Inp2,$Outp1)=@_;
	open(A,"$Inp1");
	while(<A>){
		chomp;
		($HZ,$Freq)=~/\S+/g;
		$HashFreq{$HZ}=$Freq;
	}
	close(A);

	open(A,"$Inp2");
	while(<A>){
		chomp;
		s/\d//g;#替换 将表示声调的数字去除
		($HZ,@PYs)=$_=~/\S+/g;
		foreach(@PYs){
			${$Hash_PY2HZ{$_}}{$HZ}=$HashFreq{$HZ};
		}	
	}
	close(A);
	open(OUT,">$Outp1");
	print OUT "BEG BEG\n";
	print OUT "END END\n";
	foreach(sort keys %Hash_PY2HZ){
		$Refhash=$Hash_PY2HZ{$_};
		print OUT "$_ ";
		foreach (sort{$HashFreq{$b}<=>$HashFreq{$a}} keys %{$Refhash}){#按字频由大到小输出到文件
			print OUT "$_ ";
		}
		print OUT "\n";
	}
	close OUT;
}
sub InitPY2HZ{
	my($File)=@_;
	open(In,"$File");
	while(<In>){
		chomp;
		if(/(\S+) (.*)/){
			$PY=$1;
			$HZ=$2;
			my @HZs=$HZ=~/\S+/g;
			$hashPy2HZ{$PY}=\@HZs;
		}
	}
	close(In);
}
sub GetUni{
	my($HZ)=@_;
	if(defined $HashUni{$HZ}){
		return $HashUni{$HZ};
	}
	return -1000;
}
sub GetBi{
	my($HZ1,$HZ2)=@_;
	if(defined ${$hashBi{$HZ1}}{$HZ2}){
		return ${$hashBi{$HZ1}}{$HZ2};
	}
	return -1000;
}
sub Buildlattice{
	my($Inp,$RefLattice)=@_;
	StrToArr($Inp,"PINYIN.txt");
	unshift(@Pys,"BEG");
	push(@Pys,"END");
	for($i=0;$i<@Pys;$i++){
		my @OneColumn=();
		@Candidate=();
		GetAllCandidate($Pys[$i],\@Candidate);
		foreach (@Candidate){
			my @OneUnit=();
			$OneUnit[0]=$Pys[$i];	
			$OneUnit[1]=$_;	
			$OneUnit[2]=0;	
			$OneUnit[3]=0;
			push(@OneColumn,\@OneUnit);
		}
		push(@{$RefLattice},\@OneColumn);
	}
}
sub StrToArr{
	my($inp,$file)=@_;
	chomp($inp);
	open(In,$file);
	
	while(<In>){
		chomp;
		unless($_=~/.* .*/){#当是单字拼音时,哈希赋值
			$hash_py{$_}=1;
		}
	}
	while(length($inp)>0){#利用最大长度匹配算法,匹配到拼音之后存入数组
		for($i=length($inp);$i>1;$i--){
			my $Tmp=substr($inp,0,$i);
			if(defined $hash_py{$Tmp}){
				last;
			}
		}
		$segment=substr($inp,0,$i);
		push(@Pys,$segment);
		$inp=substr($inp,$i,length($inp)-$i);
	}
	close(In);
}
sub	GetAllCandidate{
	my($PY,$refcandidate)=@_;
	if ( defined $hashPy2HZ{$PY} ){
			$RefHZ=$hashPy2HZ{$PY};
			push(@{$refcandidate},@{$RefHZ});
  }
}
sub Search{
	my($RefLattich)=@_;
	for($i=1;$i<@{$RefLattich};$i++){
		$RefCurrent=${$RefLattich}[$i];
		foreach $RefCurHZ(@{$RefCurrent}){
			$Max=-1e1000;
			$Num=0;
			$RefPrevious=${$RefLattich}[$i-1];
			foreach $RefPrevHZ(@$RefPrevious){
			$Val=GetProb(${$RefPrevHZ}[1],${$RefCurHZ}[1])+${$RefPrevHZ}[2];
				if ( $Val > $Max){
					$Max=$Val;
					$MaxProb=$Num;
				}
				$Num++;
			}
			${$RefCurHZ}[2]=$Max;
		  ${$RefCurHZ}[3]=${$RefPrevious}[$MaxProb];
		}
	}	
}
sub Backward{
	my ($RefLattich)=@_;
  my $RefEnd=${$RefLattich}[@$RefLattich-1];
  $BackPointer=${${$RefEnd}[0]}[3];
	my @ResultArray;
	while( ${$BackPointer}[3] != 0 ){
	$Pair=${$BackPointer}[1];
		unshift(@ResultArray,$Pair);
		$BackPointer=${$BackPointer}[3];
	}
	my $Result=join("",@ResultArray);
	return $Result;
}
sub GetProb{
	my($HZ1,$HZ2)=@_;
	if ($HZ1 eq "BEG" ){
		$Val=GetUni($HZ2);
	}elsif ($HZ2 eq "END" ){
		$Val=0.0;
	}else{
		$Val=GetBi($HZ1,$HZ2);
	}
	return $Val;
}
	
