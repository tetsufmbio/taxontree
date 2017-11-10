#!/bin/bash
# set -x

echo
echo "        TaxOnTree  Copyright (C) 2015-2017  Tetsu Sakamoto"
echo "        This program comes with ABSOLUTELY NO WARRANTY."
echo "        This is free software, and you are welcome to redistribute it under"
echo "        certain conditions. See GNU general public license v.3 for details."
echo

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cd $DIR
TOT=$HOME/.taxontree

# preparing folder .taxontree
if [ ! -d $TOT ]
then
	mkdir $TOT
fi

# pick email address
echo "# TaxOnTree requires your email address to retrieve information from NCBI or Uniprot Server."
read -p "# Please provide a valid email address: " email
export TAXONTREEMAIL=$email
perl -e 'use lib "./libs/lib/perl5";use Mail::RFC822::Address qw(valid); if (!valid($ENV{TAXONTREEMAIL})){exit 1}'
validemail=$?
if [ $validemail -ne 0 ]
then
	echo
	echo "ERROR: invalid email address provided."
	echo "Script interrupted."
	echo
	exit;
fi

echo
echo "# Do you want to configure TaxOnTree to access your MySQL database?"
echo "# This is optional and is only needed if you intend to load TaxOnTree tables on MySQL."
read -p "# [y/N]:" answer
while [ ! -z $answer ] && [ ${answer,,} != "y" ] && [ ${answer,,} != "n" ]
do 
	echo # ERROR: invalid answer. Answer with "y" or "n".
	read -p "# [y/N]:" answer
done

cp -f ./config/CONFIG.xml ./config/CONFIG.xml.tmp
sed -i.bak "s/<email>.*<\/email>/<email>$TAXONTREEMAIL<\/email>/" ./config/CONFIG.xml.tmp
export TAXONTREEMAIL=

if [ ! -z $answer ] && [ $answer = "y" ]
then
	read -p "# Enter your mysql username: " mysqluser
	read -sp "# Enter the password of user $mysqluser: " mysqlpass
	sed -i.bak "s/<user>.*<\/user>/<user>$mysqluser<\/user>/" ./config/CONFIG.xml.tmp
	sed -i.bak "s/<password>.*<\/password>/<password>$mysqlpass<\/password>/" ./config/CONFIG.xml.tmp

	echo
fi

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
	cd $SRC/trimAl/source;
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

	return $makeval
}

# compiling muscle
function compile_muscle {
	cd $SRC/muscle3.8.31/src;
	software=muscle
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

	return $makeval
}

# compiling FastTree
function compile_fasttree {
	cd $SRC/FastTree;
	software=FastTree
	echo "# compiling $software..." | tee -a $LOG

	if [ -e FastTree ]
	then
		rm FastTree;	
	fi

	gcc -O3 -finline-functions -funroll-loops -Wall -o FastTree FastTree.c -lm >> $LOG 2>&1;
	makeval=$?
	if [ $makeval -eq 0 ]
	then
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

	return $makeval
}

# compiling argtable2 (required by clustalo)
function compile_argtable2 {
	cd $SRC/argtable2-13;
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

	return $makeval
}

# compiling clustal omega
function compile_clustalo {
	cd $SRC/clustal-omega-1.2.1;
	software=clustalo
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

	return $makeval
}

# compiling kalign
function compile_kalign {
	cd $SRC/kalign;
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

	return $makeval
}

# compiling perl module Net::SSLeay
function compile_netssleay {
	software="Net::SSLeay"
	echo "# installing $software..." | tee -a $LOG
	echo "  testing $software..." | tee -a $LOG
	perl -e 'use Net::SSLeay' >> $LOG 2>&1;
	makeval=$?
	if [ $makeval -eq 0 ]
	then
		echo "  Perl module $software is already installed. Nothing to do."  | tee -a $LOG
	else
		echo "  Perl module $software not installed. Trying to install it."  | tee -a $LOG
		cd $SRC/perl_module/Net-SSLeay-1.82
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

	return $makeval
}

# compiling third-party software
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

cp -rf $BIN $TOT
rm -rf $BIN
cp -rf $LIBS $TOT

if [ -d $TOT/libs/lib64 ]
then
	rm -rf $TOT/libs/lib64
fi
ln -s $TOT/libs/lib $TOT/libs/lib64

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

echo | tee -a $LOG
echo "Installation finished!" | tee -a $LOG
echo | tee -a $LOG
