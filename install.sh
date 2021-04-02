#!/bin/bash
# set -x

echo
echo "        TaxOnTree  Copyright (C) 2015-2021  Tetsu Sakamoto"
echo "        This program comes with ABSOLUTELY NO WARRANTY."
echo "        This is free software, and you are welcome to redistribute it under"
echo "        certain conditions. See GNU general public license v.3 for details."
echo

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
WGET="wget --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 20"

cd $DIR
TOT=$HOME/.taxontree
# preparing folder .taxontree
read -p "# Set the path where TaxOnTree will be installed [$TOT]:" USERDIR

if [ ! -z $USERDIR ]
then
	TOT=$USERDIR
fi

if [ ! -d $TOT ]
then
	mkdir $TOT
	if [ $? -ne 0 ]
	then
		echo
		echo "# ERROR: can't create the folder $TOT."
		echo "# Script interrupted."
		echo
		exit
	fi
else
	echo "# WARNING: the folder $TOT already exists. The script may overwrite some files."
	answer="no answer"
	
	while [[ ! -z $answer && ${answer,,} != "y" && ${answer,,} != "n" ]]
	do 
		read -p "# Continue? [y/N]:" answer
		if [ -z $answer ] || [ ${answer,,} == "n" ]
		then
			echo "# Script interrupted"
			exit
		elif [ ${answer,,} == "y" ]
		then
			break
		else
			echo '# ERROR: invalid answer. Answer with "y" or "n".'
		fi
	done

fi

# get absolute path
TOT=$(cd "$(dirname "$TOT")"; pwd)/$(basename "$TOT")
echo

# pick email address
validemail=1
echo "# TaxOnTree requires your email address to retrieve information from NCBI or Uniprot Server."
while [ $validemail -ne 0 ]
do
	read -p "# Please provide a valid email address: " email
	export TAXONTREEMAIL=$email
	perl -e 'use lib "./libs/lib/perl5";use Mail::RFC822::Address qw(valid); if (!valid($ENV{TAXONTREEMAIL})){exit 1}'
	validemail=$?
	if [ $validemail -ne 0 ]
	then
		echo "# ERROR: invalid email address provided."
		echo
	fi
done

echo

cp -f ./config/CONFIG.xml ./config/CONFIG.xml.tmp
sed -i.bak "s%<email>.*</email>%<email>$TAXONTREEMAIL</email>%" ./config/CONFIG.xml.tmp
sed -i.bak "s%<generalPath></generalPath>%<generalPath>$TOT/bin</generalPath>%" ./config/CONFIG.xml.tmp
export TAXONTREEMAIL=

#echo "# Do you want to configure TaxOnTree to access your MySQL database?"
#echo "# This is optional and is only needed if you intend to load TaxOnTree tables on MySQL."
#read -p "# [y/N]:" answer
#while [ ! -z $answer ] && [ ${answer,,} != "y" ] && [ ${answer,,} != "n" ]
#do 
#	echo # ERROR: invalid answer. Answer with "y" or "n".
#	read -p "# [y/N]:" answer
#done

#if [ ! -z $answer ] && [ $answer = "y" ]
#then
#	read -p "# Enter your mysql username: " mysqluser
#	read -sp "# Enter the password of user $mysqluser: " mysqlpass
#	sed -i.bak "s/<user>.*<\/user>/<user>$mysqluser<\/user>/" ./config/CONFIG.xml.tmp
#	sed -i.bak "s/<password>.*<\/password>/<password>$mysqlpass<\/password>/" ./config/CONFIG.xml.tmp
#
#	echo
#fi

mv ./config/CONFIG.xml.tmp $TOT/CONFIG.xml
rm ./config/CONFIG.xml.tmp.bak

find . -exec touch {} \;
LOG=$DIR/log.txt

if [ -e $LOG ]
then
	rm $LOG
fi

if [ -d $DIR/bin ]
then
	rm -rf $DIR/bin
fi

declare -a MISSING=()

mkdir bin
BIN=$DIR/bin
SRC=$DIR/src
LIBS=$DIR/libs

# compiling trimal
function compile_trimal {
	
	software=trimAl
	cd $SRC
	$WGET https://github.com/scapella/trimal/archive/trimAl.zip
	unzip trimAl.zip
	rm trimAl.zip
	cd trimal-trimAl/source
	
	#cd $SRC/trimAl/source;
	echo "# compiling $software..." | tee -a $LOG

	make clean > /dev/null;
	make >> $LOG 2>&1;
	makeval=$?
	if [ $makeval -eq 0 ]
	then
		cp trimal $BIN
		echo "  $software compiled." | tee -a $LOG

	else
		echo "  ERROR: Could not compile $software." | tee -a $LOG
	fi

	if [ $makeval -ne 0 ]
	then
		MISSING[${#MISSING[@]}]=$software
	fi
	
	cd $SRC
	rm -rf trimal-trimAl
	
	return $makeval
}

# compiling muscle
function compile_muscle {

	software=muscle
	cd $SRC	
	
	echo "# downloading $software executable..." | tee -a $LOG
	$WGET https://www.drive5.com/muscle/downloads3.8.31/muscle3.8.31_i86linux64.tar.gz
	tar -zxf muscle3.8.31_i86linux64.tar.gz
	rm muscle3.8.31_i86linux64.tar.gz
	mv muscle3.8.31_i86linux64 muscle
	./muscle -version
	makeval=$?
	
	if [ $makeval -eq 0 ]
	then
		mv muscle $BIN
		echo "#  $software executable successfully tested." | tee -a $LOG
		return $makeval
	fi
	
	echo "# $software executable not working..." | tee -a $LOG
	echo "# downloading $software source code..." | tee -a $LOG
	rm muscle;
	$WGET https://www.drive5.com/muscle/downloads3.8.31/muscle3.8.31_src.tar.gz
	tar -zxf muscle3.8.31_src.tar.gz
	rm muscle3.8.31_src.tar.gz
	cd muscle3.8.31/src
	
	#cd $SRC/muscle3.8.31/src;
	echo "# compiling $software..." | tee -a $LOG

	if [ -e muscle ]
	then
		rm muscle;	
	fi

	make >> $LOG 2>&1;
	makeval=$?
	if [ $makeval -eq 0 ]
	then
		cp muscle $BIN
		rm muscle;
		echo "  $software compiled." | tee -a $LOG
	else
		echo "  ERROR: Could not compile $software." | tee -a $LOG
	fi

	if [ $makeval -ne 0 ]
	then
		MISSING[${#MISSING[@]}]=$software
	fi
	
	cd $SRC
	rm -rf muscle3.8.31
	
	return $makeval
}

# compiling FastTree
function compile_fasttree {

	software=FastTree
	cd $SRC
	
	$WGET http://www.microbesonline.org/fasttree/FastTree
	chmod +x FastTree
	./FastTree -expert
	makeval=$?
	
	if [ $makeval -eq 0 ]
	then
		mv FastTree $BIN
		echo "#  $software executable successfully tested." | tee -a $LOG
		return $makeval
	fi
	
	echo "# $software executable not working..." | tee -a $LOG
	echo "# downloading $software source code..." | tee -a $LOG
	rm FastTree;
	
	mkdir $SRC/FastTree
	cd $SRC/FastTree
	$WGET http://www.microbesonline.org/fasttree/FastTree.c
	
	#cd $SRC/FastTree;
	echo "# compiling $software..." | tee -a $LOG

	if [ -e FastTree ]
	then
		rm FastTree;	
	fi

	gcc -O3 -finline-functions -funroll-loops -Wall -o FastTree FastTree.c -lm >> $LOG 2>&1;
	makeval=$?
	if [ $makeval -eq 0 ]
	then
		# test FastTree
		./FastTree sample.fasta >> $LOG 2>&1
		testval=$?
		if [ $testval -ne 0 ]
		then
			echo "  FastTree test failed. Trying to recompile it without SSE3."
			gcc -DNO_SSE -O3 -finline-functions -funroll-loops -Wall -o FastTree FastTree.c -lm >> $LOG 2>&1;
			./FastTree sample.fasta >> $LOG 2>&1
			testval=$?
			if [ $testval -ne 0 ] 
			then
				echo "  ERROR: Could not compile $software." | tee -a $LOG
				MISSING[${#MISSING[@]}]=$software
				return $testval
			fi
		fi
		cp FastTree $BIN
		rm FastTree;
		echo "  $software compiled." | tee -a $LOG
	else
		echo "  ERROR: Could not compile $software." | tee -a $LOG
	fi

	if [ $makeval -ne 0 ]
	then
		MISSING[${#MISSING[@]}]=$software
	fi
	
	cd $SRC
	rm -rf FastTree
	
	return $makeval
}

# compiling argtable2 (required by clustalo)
function compile_argtable2 {
	
	cd $SRC
	
	$WGET http://prdownloads.sourceforge.net/argtable/argtable2-13.tar.gz
	tar -zxf argtable2-13.tar.gz
	rm argtable2-13.tar.gz
	cd argtable2-13
	#cd $SRC/argtable2-13;
	
	software=argtable2
	echo "# compiling $software..." | tee -a $LOG
	make clean > /dev/null 2>&1;
	( ./configure --prefix=$PWD && make && make install ) >> $LOG 2>&1;
	makeval=$?
	if [ $makeval -eq 0 ]
	then
		echo "  $software compiled." | tee -a $LOG
		param1="-I$PWD/include"
		param2="-L$PWD/lib"
		compile_clustalo $param1 $param2
	else
		echo "  ERROR: Could not compile $software." | tee -a $LOG
		MISSING[${#MISSING[@]}]=clustalo
	fi
	
	cd $SRC
	rm -rf argtable2-13
	
	return $makeval
}

# compiling clustal omega
function compile_clustalo {

	software=clustalo
	cd $SRC
	
	$WGET http://www.clustal.org/omega/clustalo-1.2.4-Ubuntu-x86_64
	mv clustalo-1.2.4-Ubuntu-x86_64 clustalo
	chmod +x clustalo
	./clustalo --version
	makeval=$?
	
	if [ $makeval -eq 0 ]
	then
		mv clustalo $BIN
		
		echo "#  $software executable successfully tested." | tee -a $LOG
		return $makeval
	fi
	
	echo "# $software executable not working..." | tee -a $LOG
	echo "# downloading $software source code..." | tee -a $LOG
	rm clustalo;
	
	if [ ! -d "clustal-omega-1.2.4" ]
	then
		$WGET http://www.clustal.org/omega/clustal-omega-1.2.4.tar.gz
		tar -zxf clustal-omega-1.2.4.tar.gz
		rm clustal-omega-1.2.4.tar.gz
	fi
	
	cd clustal-omega-1.2.4;
	
	echo "# compiling $software..." | tee -a $LOG
	make clean > /dev/null 2>&1;
	if [ $# -eq 0 ]
	then
		./configure >> $LOG 2>&1;
	else
		./configure CFLAGS=$1 LDFLAGS=$2 >> $LOG 2>&1;
	fi
	make >> $LOG 2>&1;
	makeval=$?
	
	if [ $makeval -eq 0 ]
	then
		cp src/clustalo $BIN
		echo "  $software compiled." | tee -a $LOG
	else
		echo "  ERROR: Could not compile $software."
		if [ $# -eq 0 ]
		then
			echo "  Probably argtable2 is missing. Trying to compile argtable2." | tee -a $LOG
			compile_argtable2
		else
			echo "  ERROR: Could not compile $software." | tee -a $LOG
			MISSING[${#MISSING[@]}]=$software
		fi
	fi
	
	cd $SRC
	rm -rf clustal-omega-1.2.4
	
	return $makeval
}

# compiling kalign
function compile_kalign {

	mkdir $SRC/kalign
	cd $SRC/kalign
	$WGET http://msa.sbc.su.se/downloads/kalign/current.tar.gz
	tar -zxf current.tar.gz
	rm current.tar.gz
	
	#cd $SRC/kalign;
	software=kalign
	echo "# compiling $software..." | tee -a $LOG

	make clean > /dev/null 2>&1;
	./configure >> $LOG 2>&1;
	make >> $LOG 2>&1;
	makeval=$?
	if [ $makeval -eq 0 ]
	then
		cp kalign $BIN
		echo "  $software compiled." | tee -a $LOG
	else
		echo "  ERROR: Could not compile $software." | tee -a $LOG
	fi
	
	if [ $makeval -ne 0 ]
	then
		MISSING[${#MISSING[@]}]=$software
	fi

	cd $SRC
	rm -rf kalign
	
	return $makeval
}

# compiling perl module Net::SSLeay
function compile_netssleay {
	
	software="Net::SSLeay"
	echo "#  Verifying $software..." | tee -a $LOG
	perl -e 'use Net::SSLeay' >> $LOG 2>&1;
	makeval=$?
	if [ $makeval -eq 0 ]
	then
		echo "#  Perl module $software is already installed. Nothing to do."  | tee -a $LOG
	else
		echo "# installing $software..." | tee -a $LOG
		
		echo "#  Perl module $software not installed."  | tee -a $LOG
		answer="no answer"
		while [[ ! -z $answer && ${answer,,} != "y" && ${answer,,} != "n" ]]
		do 
			read -p "# Should this script download its source code and install it? [Y/n]" answer
			if [ ${answer,,} == "n" ]
			then
				echo "# OK, this script should be installed manually."
				MISSING[${#MISSING[@]}]=$software
				return 1
			elif [ -z $answer ] || [ ${answer,,} == "y" ]
			then
				echo "# OK, downloading and installing $software."
				break
			else
				echo '# ERROR: invalid answer. Answer with "y" or "n".'
			fi
		done
		
		cd $SRC
		$WGET https://cpan.metacpan.org/authors/id/C/CH/CHRISN/Net-SSLeay-1.90.tar.gz
		tar -zxf Net-SSLeay-1.90.tar.gz
		rm Net-SSLeay-1.90.tar.gz
		cd Net-SSLeay-1.90
		
		#cd $SRC/perl_module/Net-SSLeay-1.82
		printf 'n\n' | make realclean >> /dev/null 2>&1;
		printf 'n\n' | perl Makefile.PL PREFIX=$TOT/libs >> $LOG 2>&1;
		make >> $LOG 2>&1;
		make install >> $LOG 2>&1;
		makeval=$?
		if [ $makeval -ne 0 ]
		then
			echo "  ERROR: Can't install Perl module $software. Probably OpenSSL is missing."  | tee -a $LOG
			echo "         Verify if the package openssl-devel is installed in your machine."  | tee -a $LOG
			echo "         If not, try to run this script again after installing openssl-devel."  | tee -a $LOG
			echo "         For more info about OpenSSL, see https://www.openssl.org/"  | tee -a $LOG
		else
			echo "  $software installed."  | tee -a $LOG
		fi		
	fi
	
	if [ $makeval -ne 0 ]
	then
		MISSING[${#MISSING[@]}]=$software
	fi
	
	cd $SRC
	rm -rf Net-SSLeay-1.90
	
	return $makeval
}

# compiling third-party software
answer="no answer"
echo "# To use the phylogenetic pipeline on TaxOnTree, some third-party software are necessary."
echo "# Software that'll be installed: trimal, muscle, clustalo, kalign, fasttree."
while [[ ! -z $answer && ${answer,,} != "y" && ${answer,,} != "n" ]]
do 
	read -p "# Should this script download their source code and install them? [Y/n]" answer
	if [ ${answer,,} == "n" ]
	then
		echo "# OK, skiping this step."
	elif [ -z $answer ] || [ ${answer,,} == "y" ]
	then
		echo "# OK, downloading and installing them."
		compile_trimal
		echo | tee -a $LOG
		compile_muscle
		echo | tee -a $LOG
		compile_fasttree
		echo | tee -a $LOG
		compile_clustalo
		echo | tee -a $LOG
		compile_kalign
		echo | tee -a $LOG
	else
		echo '# ERROR: invalid answer. Answer with "y" or "n".'
	fi
done

cp -rf $BIN $TOT
rm -rf $BIN
cp -rf $LIBS $TOT

if [ -d $TOT/libs/lib64 ]
then
	rm -rf $TOT/libs/lib64
fi
ln -s $TOT/libs/lib $TOT/libs/lib64

# change path of perl libraries in taxontree.pm
sed -i.bak "8s%.*%BEGIN { \$installFolder  = \"$TOT\"; }%" $TOT/libs/lib/perl5/taxontree.pm
rm $TOT/libs/lib/perl5/taxontree.pm.bak

# installing 
compile_netssleay
echo | tee -a $LOG

echo "NOTE: All installed dependencies are in $TOT"
echo | tee -a $LOG

if [ ${#MISSING[@]} -gt 0 ]
then
	echo "NOTE: Some software couldn't be installed automatically. They are:" | tee -a $LOG
	for var in "${MISSING[@]}"
	do
		echo "* $var"  | tee -a $LOG
	done
	echo "Please, try to installed than manually in your system."
else
	echo "All dependencies were installed successfully!"
fi

cp -f $SRC/taxontree $DIR
sed -i.bak "57s%.*%use lib '$TOT/libs/lib/perl5';%" $DIR/taxontree
rm $DIR/taxontree.bak

echo | tee -a $LOG
echo "# taxontree executable created in $DIR"
echo "# Try executing ./taxontree -version"

echo | tee -a $LOG
echo "Installation finished!" | tee -a $LOG
echo | tee -a $LOG
echo
