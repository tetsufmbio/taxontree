#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cd $DIR
LOG=$DIR/log.txt

if [ -e $LOG ]
then
	rm $LOG
fi

if [ -d $DIR/bin ]
then
	rm -rf $DIR/bin
fi

mkdir bin
BIN=$DIR/bin 
SRC=$DIR/src

# compiling trimal
function compile_trimal {
	
	cd $SRC/trimAl/source;
	software=trimAl
	echo compiling $software... | tee -a $LOG

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
	return $makeval
}

# compiling muscle
function compile_muscle {
	cd $SRC/muscle3.8.31/src;
	software=muscle
	echo compiling $software... | tee -a $LOG

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
	return $makeval
}

# compiling FastTree
function compile_fasttree {
	cd $SRC/FastTree;
	software=FastTree
	echo compiling $software... | tee -a $LOG

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
	return $makeval
}

# compiling argtable2 (required by clustalo)
function compile_argtable2 {
	cd $SRC/argtable2-13;
	software=argtable2
	echo compiling $software... | tee -a $LOG
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
	fi
	return $makeval
}

# compiling clustal omega
function compile_clustalo {
	cd $SRC/clustal-omega-1.2.1;
	software=clustalo
	echo compiling $software... | tee -a $LOG
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
		fi
	fi
	return $makeval
}

# compiling kalign
function compile_kalign {
	cd $SRC/kalign;
	software=kalign
	echo compiling $software... | tee -a $LOG

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
	return $makeval
}

# compiling perl module Net::SSLeay
function compile_netssleay {
	software="Net::SSLeay"
	echo testing $software... | tee -a $LOG
	perl -e 'use Net::SSLeay' >> $LOG 2>&1;
	testval = $?
	if [ $testval -eq 0 ]
	then
		echo Perl module $software is installed. Nothing to do.  | tee -a $LOG
	else
		echo Perl module $software not installed. Trying to install it.  | tee -a $LOG
		cd $SRC/perl_module/Net-SSLeay-1.82
		make clean  >> /dev/null 2>&1;
		echo "n" | perl Makefile.PL PREFIX=$DIR >> $LOG 2>&1;
		make >> $LOG 2>&1;
		make install >> $LOG 2>&1;
		cd $DIR/lib
		if [ -d $DIR/lib64 ]
		then
			cp -r ../lib64/perl5 .
			rm -rf $DIR/lib64
		fi
		cp -r ../share .
		rm -rf $DIR/share
		
	fi
}

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
compile_netssleay
echo | tee -a $LOG