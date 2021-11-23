#!/usr/bin/perl -w

package taxontree;
use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
my $installFolder;
BEGIN { $installFolder  = $ENV{'HOME'}."/.taxontree"; }
use lib $installFolder."/libs/lib/perl5";
use Mail::RFC822::Address qw(valid);
use URI::Escape;
use HTTP::Tiny;
use XML::Simple qw(XMLin);
use File::Which;
#use Data::Dumper;
use Net::Wire10;

use Bio::TreeIO;
use Bio::Tree::TreeFunctionsI;
use Bio::Tree::TreeI;
use Bio::Tree::NodeI;
	
$VERSION     = "1.10.3";
@ISA         = qw(Exporter);
@EXPORT      = qw(inputs check main);
#@EXPORT_OK   = qw(input);

# parameters
my $querySeqFile;
my $queryList;
my $querySingleID;
my $queryBlastFile;
my $treeFile;
my $queryAlignmentFile;
my $queryMFastaFile;
my $queryID;
my $treeTable;
my $otherTable;
my $treeProg;
my $trimProg;
my $treeFormat;
my $queryTax;
my $queryKO;
my $queryUEKO;
my $queryGeneName;
my $queryGene;
my $delimiter;
my $position;
my $posTax;
my $txidMap;
my $pid;
my $showIsoform;
my $noTrimal;
my $database;
my $databasecmd;
my $blastProgram;
my $aligner;
my $leafNameFormat;
my $taxRepFormat;
my $lcaLimit;
my $lcaLimitDown;
my $tpident_cut;
my $maxTarget;
my $maxTargetBlast;
my $taxSimple;
my $treeRoot;
my $printLeaves;
my $evalue;
my $numThreads;
my $localMySQL;
my $webBlastDelimiter;
my $webBlastPosition;
my $taxFilter;
my $taxFilterCat;
my $restrictTax;
my $forceNoTxid;
my $forceNoInternet;

my $TaxOnTreeVersion;

sub inputs {
	my $inputs = $_[0];
	$querySeqFile = $inputs->{"querySeqFile"};
	$queryList = $inputs->{"queryList"};
	$querySingleID = $inputs->{"querySingleID"};
	$queryBlastFile = $inputs->{"queryBlastFile"};
	$treeFile = $inputs->{"treeFile"};
	$queryAlignmentFile = $inputs->{"queryAlignmentFile"};
	$queryMFastaFile = $inputs->{"queryMFastaFile"};
	$queryID = $inputs->{"queryID"},
	$treeTable = $inputs->{"treeTable"};
	$otherTable = $inputs->{"otherTable"};
	$treeProg = $inputs->{"treeProg"};
	$trimProg = $inputs->{"trimProg"};
	$treeFormat = $inputs->{"treeFormat"};
	$queryTax = $inputs->{"queryTax"};
	$queryKO = $inputs->{"queryKO"};
	$queryUEKO = $inputs->{"queryUEKO"};
	$queryGeneName = $inputs->{"queryGeneName"};
	$queryGene = $inputs->{"queryGene"};
	$delimiter = $inputs->{"delimiter"};
	$position = $inputs->{"position"};
	$posTax = $inputs->{"posTax"};
	$txidMap = $inputs->{"txidMap"};
	$pid = $inputs->{"pid"};
	$showIsoform = $inputs->{"showIsoform"};
	$noTrimal = $inputs->{"noTrimal"};
	$database = $inputs->{"database"};
	$databasecmd = $inputs->{"databasecmd"};
	$blastProgram = $inputs->{"blastProgram"};
	$aligner = $inputs->{"aligner"};
	$leafNameFormat = $inputs->{"leafNameFormat"};
	$taxRepFormat = $inputs->{"taxRepFormat"};
	$lcaLimit = $inputs->{"lcaLimit"};
	$lcaLimitDown = $inputs->{"lcaLimitDown"};
	$tpident_cut = $inputs->{"tpident_cut"};
	$maxTarget = $inputs->{"maxTarget"};
	$maxTargetBlast = $inputs->{"maxTargetBlast"};
	$taxSimple = $inputs->{"taxSimple"};
	$treeRoot = $inputs->{"treeRoot"};
	$printLeaves = $inputs->{"printLeaves"};
	$evalue = $inputs->{"evalue"};
	$numThreads = $inputs->{"numThreads"};
	$localMySQL = $inputs->{"localMySQL"};
	$webBlastDelimiter = $inputs->{"webBlastDelimiter"};
	$webBlastPosition = $inputs->{"webBlastPosition"};
	$taxFilter = $inputs->{"taxFilter"};
	$taxFilterCat = $inputs->{"taxFilterCat"};
	$restrictTax = $inputs->{"restrictTax"};
	$forceNoTxid = $inputs->{"forceNoTxid"};
	$forceNoInternet = $inputs->{"forceNoInternet"};
	$TaxOnTreeVersion = $_[1];
	
	if(!$databasecmd){
		$databasecmd = $database;
	}
	return 1;
}

my %programs;
my %mysqlInfo;
my $local = 0;
my $wire;
my $email;
my $internetConnection = 1;
my %restrictTax;
my %leafNameOptions;
my @leafNameOptions;
my @taxRepOptions;

sub check {
	my $url_test = "http://www.msftncsi.com/ncsi.txt";
	my $response_test = HTTP::Tiny->new->get($url_test);

	if ($response_test->{content} !~ m/Microsoft NCSI/){
		$internetConnection = 0;
	}

	if ($forceNoInternet){
		$internetConnection = 0;
	}
	
	my $configFile = $installFolder."/CONFIG.xml";
	if (!(-e $configFile)){
		if (!$treeFile or $localMySQL or $internetConnection){
			die "\nERROR: Could not locate $configFile.\n";
		}
	} else {
		
		my $xs1 = XML::Simple->new();
		my $doc = $xs1->XMLin($configFile, KeyAttr => {program => "name", table => "name"}, ForceArray => [ 'program', 'table' ], SuppressEmpty => undef);
		
		my $searchGeneralPath;
		if ($doc->{"generalPath"}){
			$searchGeneralPath = $doc->{"generalPath"};
		} else {
			$searchGeneralPath = "";
		}

		# check email
		if ($internetConnection){
			if ($doc->{"email"}){
				$email = $doc->{"email"};
			} 
			if (!$email){
				die "\nERROR: No email address provided. Please set an email address in CONFIG.xml.\n";
			} elsif (!valid($email)){
				die "\nERROR: Email set at CONFIG.xml is not valid. Please check it.\n";
			}
		}
		
		if (-e $ENV{'HOME'}."/.taxontree/bin"){
			$searchGeneralPath .= ":".$ENV{'HOME'}."/.taxontree/bin";
		}
		# Check if third-party program are accessible

		foreach my $pipelineStep (keys %{$doc->{"programs"}}){
			foreach my $programs (keys %{$doc->{"programs"}->{$pipelineStep}->{"program"}}){
				foreach my $parameters (keys %{$doc->{"programs"}->{$pipelineStep}->{"program"}->{$programs}}){
					$programs{$pipelineStep}{$programs}{$parameters} = $doc->{"programs"}->{$pipelineStep}->{"program"}->{$programs}->{$parameters};
				}
			}
		}

		my %blast_db = (
			'refseq_protein' => 1,
			'nr' => 1,
		);

		$local = 1 if (!(exists $blast_db{$database}));

		if ($querySeqFile or $queryList or $querySingleID or $queryBlastFile or $queryMFastaFile){
			# Check aligner
			
			if (exists $programs{"aligners"}{$aligner}){
				my $paths2verify = "";

				if ($programs{"aligners"}{$aligner}{"path"}){
					$programs{"aligners"}{$aligner}{"path"} =~ s/\/$//;
					$paths2verify .= $programs{"aligners"}{$aligner}{"path"};
				}
				$paths2verify .= ":".$searchGeneralPath;
				$paths2verify =~ s/:$//;
				$programs{"aligners"}{$aligner}{"path"} = checkSoftware($aligner, $paths2verify);		
			} else {
				die "\nERROR: Selected aligner (".$aligner.") is not configured in CONFIG.xml.\n";
			}
			
			# Check if local blast is accessible:
			
			if ($local == 1){
				# Check blastp
				if ($querySeqFile or $querySingleID){
					if (exists $programs{"blastSearch"}{$blastProgram}){
						my $paths2verify = "";
						if ($programs{"blastSearch"}{$blastProgram}{"path"}){
							$programs{"blastSearch"}{$blastProgram}{"path"} =~ s/\/$//;
							$paths2verify .= $programs{"blastSearch"}{$blastProgram}{"path"};
						}
						$paths2verify .= ":".$searchGeneralPath;
						$paths2verify =~ s/:$//;
						$programs{"blastSearch"}{$blastProgram}{"path"} = checkSoftware($blastProgram, $paths2verify);		
					} else {
						die "\nERROR: $blastProgram is not configured in CONFIG.xml.\n";
					}
				}
				
				# Check blastdbcmd
				if (exists $programs{"blastSearch"}{"blastdbcmd"}){
					my $paths2verify = "";
					if ($programs{"blastSearch"}{"blastdbcmd"}{"path"}){
						$programs{"blastSearch"}{"blastdbcmd"}{"path"} =~ s/\/$//;
						$paths2verify .= $programs{"blastSearch"}{"blastdbcmd"}{"path"};
					}
					$paths2verify .= ":".$searchGeneralPath;
					$paths2verify =~ s/:$//;
					$programs{"blastSearch"}{"blastdbcmd"}{"path"} = checkSoftware("blastdbcmd", $paths2verify);		
				} else {
					die "\nERROR: blastdbcmd is not configured in CONFIG.xml.\n";
				}
				
				# Check if blast database exists
				if ($local == 1){
					my $blastdbcmdPath = $programs{"blastSearch"}{"blastdbcmd"}{"path"};
					my $databasePath = $database;
					if ($databasePath =~ /\//){
						$databasePath = substr($databasePath, 0, rindex($databasePath, "/"));
					} else {
						$databasePath = "./"
					}
					
					my $command = $blastdbcmdPath." -list ".$databasePath;
					my $commandResult = `$command`;
					if (!($commandResult =~ m/$database /)){
						die "\nERROR: $database was not found...\n";
					}
					
					if($database ne $databasecmd){
						$databasePath = $databasecmd;
						if ($databasePath =~ /\//){
							$databasePath = substr($databasePath, 0, rindex($databasePath, "/"));
						} else {
							$databasePath = "./"
						}
						
						$command = $blastdbcmdPath." -list ".$databasePath;
						$commandResult = `$command`;
						if (!($commandResult =~ m/$database /)){
							die "\nERROR: $database was not found...\n";
						}
						
					}

				}
			}
		}

		if (!$treeFile){

			# Check Tree Generator
			if (exists $programs{"treeReconstruction"}{$treeProg}){
				my $paths2verify = "";
				if ($programs{"treeReconstruction"}{$treeProg}{"path"}){
					$programs{"treeReconstruction"}{$treeProg}{"path"} =~ s/\/$//;
					$paths2verify .= $programs{"treeReconstruction"}{$treeProg}{"path"};
				}
				$paths2verify .= ":".$searchGeneralPath;
				$paths2verify =~ s/:$//;
				$programs{"treeReconstruction"}{$treeProg}{"path"} = checkSoftware($treeProg, $paths2verify);		
			} else {
				die "\nERROR: Selected tree generator software (".$treeProg.") is not configured in CONFIG.xml.\n";
			}

			if ($trimProg ne "false"){
				if (exists $programs{"trimming"}{$trimProg}){
					my $paths2verify = "";
					if ($programs{"trimming"}{$trimProg}{"path"}){
						$programs{"trimming"}{$trimProg}{"path"} =~ s/\/$//;
						$paths2verify .= $programs{"trimming"}{$trimProg}{"path"};
					}
					$paths2verify .= ":".$searchGeneralPath;
					$paths2verify =~ s/:$//;
					$programs{"trimming"}{$trimProg}{"path"} = checkSoftware($trimProg, $paths2verify);		
				} else {
					die "\nERROR: Selected alignment refiner software (".$trimProg.") is not configured in CONFIG.xml.\n";
				}
			} else {
				$noTrimal = 1;
			}
		}

		# check for local database in mysql
		
		if ($localMySQL){
			foreach my $mysqlInfo (keys %{$doc->{"mysql"}}){
				$mysqlInfo{$mysqlInfo} = $doc->{"mysql"}->{$mysqlInfo};
			}

			if ($mysqlInfo{"host"} && $mysqlInfo{"user"} && $mysqlInfo{"password"} && $mysqlInfo{"database"}){
				$wire = Net::Wire10->new(
					query_timeout => 300,
					host     => $mysqlInfo{"host"},
					user     => $mysqlInfo{"user"},
					port     => $mysqlInfo{"port"},
					password => $mysqlInfo{"password"},
					database => $mysqlInfo{"database"}
				);
				eval {$wire->connect;};
				if ($@) {
					die "\nERROR: Could not connect to MySQL database. Please check mysql parameters in CONFIG.xml\n";
				} else {
					print "Connected to MySQL database.\n";
					$mysqlInfo{"connection"} = 1;
					
					my %configuredTables;

					foreach my $configuredTable (keys %{$doc->{"mysql"}->{"tables"}->{"table"}}){
						my $tableName = $doc->{"mysql"}->{"tables"}->{"table"}->{$configuredTable}->{"content"};
						$configuredTables{$tableName} = $configuredTable;
					}
					
					my $tables = $wire->query("SHOW TABLES;");
					while (my $row = $tables->next_array) {
						my @row = @$row;
						for(my $i = 0; $i < scalar @row; $i++){
							if (exists $configuredTables{$row[$i]}){
								$mysqlInfo{"tables"}{$configuredTables{$row[$i]}} = $row[$i];
							}
							
						}
					}
				}
			} 
		}
	} 
		
	if (!$mysqlInfo{"connection"} and $internetConnection == 0){
		die "\nERROR: You need at least an internet connection or a local database to perform the job.\n       Please, refer to README.txt.\n";
	}
	
	# check if provided leafNameFmt is appropriated

	my %leafNameType = (
		"lcan" => 1,
		"lca" => 1,
		"id" => 1,
		"accession" => 1,
		"species" => 1,
		"geneid" => 1,
		"genename" => 1,
		"geneid" => 1,
		"header" => 1
	);

	my %ranks = (
		"superkingdom" => "01-superkingdom",
		"kingdom" => "02-kingdom",
		"phylum" => "03-phylum",
		"subphylum" => "04-subphylum",
		"superclass" => "05-superclass",
		"class" => "06-class",
		"subclass" => "07-subclass",
		"superorder" => "08-superorder",
		"order" => "09-order",
		"suborder" => "10-suborder",
		"superfamily" => "11-superfamily",
		"family" => "12-family",
		"subfamily" => "13-subfamily",
		"tribe" => "14-tribe",
		"genus" => "15-genus",
		"species" => "16-species",
	);
		
	my @leafNameTmpOptions = split(";", $leafNameFormat);
	my $error = 0;
	my $identifier = 0;
	foreach my $leafType(@leafNameTmpOptions){
		$leafType = lc($leafType);
		if (!(exists $leafNameType{$leafType})){
			if ($leafType =~ m/rankcode\((.+)\)/ or $leafType =~ m/rankname\((.+)\)/){
				my $ranks = $1;
				my @ranks = split(",", $ranks);
				my @defRanks;
				foreach my $rank(@ranks){
					$ranks = lc ($rank);
					if(!(exists $ranks{$rank})){
						$error = 1;
						print "NOTE: $rank is not an appropriated rank name.\n";
					}
					push (@defRanks, $ranks{$rank});
				}
				if ($leafType =~ m/rankcode/){
					$leafType = "rankcode";
				} else {
					$leafType = "rankname";
				}
				push(@leafNameOptions, $leafType);
				$leafNameOptions{$leafType} = \@defRanks;
			} else {
				print "NOTE: $leafType is not an appropriated category to be used in leaf name.\n";
				$error = 1;
			}
		} else {
			push(@leafNameOptions, $leafType);
			$leafNameOptions{$leafType} = 1;
		}
	}

	if ($error == 1){
		die "\nERROR: something wrong in the provided leaf name format\n       Please, see the TaxOnTree manual (./taxontree -man).\n";
	}

	# check Tax Report format
	my @taxRepTmpOptions = split(";", $taxRepFormat);
	my %taxRepOptions;
	foreach my $taxRepType(@taxRepTmpOptions){
		if ($taxRepType =~ /\.\./){
			my @values = split(/\.\./, $taxRepType);
			if (scalar @values < 2 or scalar @values > 2){
				# Something wrong...
				print "NOTE: Something wrong with this sentence: $taxRepType\n";
				$error = 1;
			} else {
				if (!$values[0] or !$values[1]){
					print "NOTE: Something wrong with this sentence: $taxRepType\n";
					$error = 1;
					next;
				}
				if ($values[0] =~ /\D/ or $values[1] =~ /\D/){
					# Something wrong...
					print "NOTE: Something wrong with this sentence: $taxRepType\n";
					$error = 1;
					next;
				}
				my $minValue;
				my $maxValue;
				if ($values[0] > $values[1]){
					$minValue = $values[1];
					$maxValue = $values[0];
				} else {
					$minValue = $values[0];
					$maxValue = $values[1];
				}
				$maxValue = 17 if ($maxValue > 17);
				for (my $i = $minValue; $i <= $maxValue; $i++){
					$taxRepOptions{$i} = 1;
				}
			}
		} elsif ($taxRepType =~ /\D/){
			# Something wrong...
			print "NOTE: Something wrong with this sentence: $taxRepType\n";
			$error = 1;
			next;
		} else {
			$taxRepOptions{$taxRepType} = 1;
		}
	}
	@taxRepOptions = sort { $a <=> $b } keys %taxRepOptions;

	if ($error == 1){
		die "\nERROR: something wrong in the provided taxonomy report format\n       Please, see the TaxOnTree manual (./taxontree -man).\n";
	}
	
	# check if provided txidMap or queryTax is appropriated

	if ($queryTax){

		die "\nERROR: queryTax provided ($queryTax) has a not number character.\n" if ($queryTax =~ m/\D/);

		if ($internetConnection == 1){
			my $url_fetch_lineage = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=taxonomy&id=".$queryTax;
			my $fetch_lineage;
			my $errorCount = -1;
			do {
				my $response = HTTP::Tiny->new->get($url_fetch_lineage);
				$fetch_lineage = $response->{content};
				$errorCount++;
				sleep 1;
			} while ($fetch_lineage =~ m/<\/Error>|<title>Bad Gateway!<\/title>|<title>Service unavailable!<\/title>|Error occurred:/ and $errorCount < 5);
			if ($errorCount > 4){
				die "\nERROR: Sorry, access to NCBI server retrieved error 4 times. Please, try to run TaxOnTree again later.";
			}

			my $xs2 = XML::Simple->new();
			my $doc_lineage = $xs2->XMLin($fetch_lineage);
			
			die "\nERROR: queryTax provided ($queryTax) is not a valid taxonomy ID identifier. Please check NCBI Taxonomy website.\n" if (!(exists $doc_lineage->{"Taxon"})); 
		}
	}

	if ($txidMap){

		die "\nERROR: txidMap provided ($txidMap) has a not number character.\n" if ($txidMap =~ m/\D/);

		if ($internetConnection == 1){
			my $url_fetch_lineage = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=taxonomy&id=".$txidMap;
			my $fetch_lineage;
			my $errorCount = -1;
			do {
				my $response = HTTP::Tiny->new->get($url_fetch_lineage);
				$fetch_lineage = $response->{content};
				$errorCount++;
				sleep 1;
			} while ($fetch_lineage =~ m/<\/Error>|<title>Bad Gateway!<\/title>|<title>Service unavailable!<\/title>|Error occurred:/ and $errorCount < 5);
			if ($errorCount > 4){
				die "\nERROR: Sorry, access to NCBI server retrieved error 4 times. Please, try to run TaxOnTree again later.\n";
			}

			my $xs2 = XML::Simple->new();
			my $doc_lineage = $xs2->XMLin($fetch_lineage);
			
			die "\nERROR: txidMap provided ($txidMap) is not a valid taxonomy ID identifier. Please check NCBI Taxonomy website.\n" if (!(exists $doc_lineage->{"Taxon"})); 
		}	
	}
	
	# check restrictTax
	if ($restrictTax){
		print "\nFile containing taxonomy ID to restrict provided. Checking it.\n";
		open(RESTAX, "< $restrictTax") or die "\nERROR: Can't open the file $restrictTax";
		while(my $line = <RESTAX>){
			chomp $line;
			$line =~ s/\n|\r//g;
			next if ($line =~ /^$/);
			if ($line =~ /[^\d]/){
				print "\nNOTE: $line is not a valid taxonomy ID. This information was disconsidered.\n";
			} else {
				$restrictTax{$line} = 1;
			}
		}
		if (scalar(keys %restrictTax) == 0){
			die "\nERROR: None of taxonomy id provided was valid. Please, check it.\n";
		}
		print "\n  OK!\n";
	}

	# check taxfilter and taxfiltercat
	if ($taxFilter){
		if (!$taxFilterCat){
			die "/nERROR: -taxFilterCat not provided.\n";
		}
		if ($taxFilter =~ /[^\d]/){
			die "/nERROR: data provided in -taxFilter is not a number.\n";
		}
	}
	
	if ($taxFilterCat){
		if (!$taxFilter){
			die "/nERROR: -taxFilter not provided.\n";
		}
		$taxFilterCat = lc($taxFilterCat);
		if ($taxFilterCat ne "lca" and !exists $ranks{$taxFilterCat}){
			die "/nERROR: data provided in -taxFilterCat is not lca or a taxonomic rank.\n";
		}
	}
	
	return 1;
}

my %queryInfo;
my @test = qw(NP_000376 NP_000376.1 4502177 NP_004326 NP_004326.1 4757876 BST2_HUMAN Q10589 Q10589-2);
my %subjectInfo;
my %taxInfo;
my %map_txid;
my %missingTxid;
my %missingTaxTN;
my %generalInfo;
my %otherTableHash;
my %treeTableHash;
my %hashCode;
my %hashFileTrans;

sub main {
	my $input = $_[0];
	my $inputType = $_[1];
	
	if ($querySingleID or $querySeqFile or $queryBlastFile){
		$maxTarget = 200 if (!$maxTarget);
		if (!$maxTargetBlast) {
			if (!$showIsoform or $taxFilter or $restrictTax or $lcaLimit){
				my $multiMaxTarget = -1.173*(log($maxTarget)) + 10.3;
				$multiMaxTarget = 2 if ($multiMaxTarget < 2);
				$multiMaxTarget = 10 if ($multiMaxTarget > 10);
				$maxTargetBlast = int($multiMaxTarget * $maxTarget + 0.5);
			} else {
				$maxTargetBlast = $maxTarget;
			}
		}
	}

	$delimiter = quotemeta($delimiter);
	if ($txidMap){
		$map_txid{"txids"}{$txidMap} = {};
	}

	if ($treeTable){
		popTreeTableHash($treeTable);
	}
	
	if ($otherTable){
		popOtherTableHash($otherTable);
	}
	
	$map_txid{"txids"}{1} = {};
	querySingleID() if ($inputType eq "querySingleID");
	queryList() if ($inputType eq "queryList");
	querySeqFile() if ($inputType eq "querySeqFile");
	queryMFastaFile() if ($inputType eq "queryMFastaFile");
	queryMFastaFile() if ($inputType eq "queryAlignmentFile");
	queryBlastFile() if ($inputType eq "queryBlastFile");
	treeFile() if ($inputType eq "treeFile");
	
}

sub querySingleID {

	print "Query ID provided: $querySingleID\n";
	print "Retrieving Query info...\n";
	$queryID = $querySingleID;
	my $queryInfoRef = defineIdSubject(($queryID));
	mergeGeneralInfo($queryInfoRef);
	
	# check query info
	my @query = checkInfoTxid(($queryID));
	if (scalar @query == 0){
		die "\nERROR: Could not retrieve taxonomy id from query.\n";
	}
	
	my $sequenceInfoRef = retrieveSubjectInfo(($queryID));
	mergeGeneralInfo($sequenceInfoRef);
	
	if (!$generalInfo{$querySingleID}{"seq"}){
		die "\nERROR: Could not retrieve sequence from provided query ID.\n";
	}
	
	# fill Query info
	%queryInfo = %{$generalInfo{$querySingleID}};
	$txidMap = $queryInfo{"txid"} if (!$txidMap);
	
	my $blastResult = &executeBlast($local); # return Blast result;
	my $subjects = &formatBlastResult($blastResult); # return a list of subjects to be considered in the analysis
	my @subjects = @$subjects;
	
	print "Retrieving Subject info...\n";
	my $refDefinedID = defineIdSubject(@subjects);
	mergeGeneralInfo($refDefinedID);
	
	@subjects = checkInfoTxid(@subjects);
	@subjects = queryOnTopList(@subjects);	
	# generate seq codes
	@subjects = generateCode(@subjects);
	
	# discard isoform
	if (!($showIsoform)){
		@subjects = discardIsoform(@subjects);
		#@new_subjects = @$newGiList;
		print "  Number of proteins after discarding isoforms: ".scalar @subjects."\n";
		if (scalar @subjects < 3){
			die "\nERROR: Less than 3 proteins with distinct geneID was retrieved.\n";
		}
	}
	
	&pair2pairLCA(keys %{$map_txid{"txids"}}); # fill %map_txid;
	
	@subjects = checkTaxLin(@subjects);
	# check query info
	if (!$map_txid{"txids"}{$generalInfo{$queryID}{"txid"}}){
		die "\nERROR: Could not retrieve taxonomy information from provided query ID.\n";
	}
	
	# tax filter
	@subjects = taxonomicFilters(@subjects);
	
	if (scalar @subjects > $maxTarget){
		@subjects = splice(@subjects, 0, $maxTarget);
	}
	print "  Total number of proteins for phylogenetic analysis: ".scalar @subjects."\n";
	
	my %subjectList;
	foreach my $key(@subjects){
		$subjectList{$hashCode{"code"}{$key}{"id"}} = 1;
	}
	$sequenceInfoRef = retrieveSubjectInfo(keys %subjectList);
	mergeGeneralInfo($sequenceInfoRef);
	
	@subjects = checkSeq(@subjects);
	
	my $alignmentFile = &align($aligner, \@subjects);
	if (!($noTrimal)){
		$alignmentFile = &trimal($alignmentFile);
	}
	my $treeFile = &generateTree($alignmentFile);
	&formatTree($treeFile);
	return 1;
}

sub queryList {
	
	print "List of accession number provided: $queryList\n";
	
	open (LIST, "< $queryList") or die "\nERROR: Can't open the list file\n\n";
	my @subjects = <LIST>;
	
	# check subjects
	my @checked;
	foreach my $key(@subjects){
		chomp $key;
		$key =~ s/\r\n//g;
		if ($key !~ /^$/){
			push (@checked, $key);
		}
	}
	@subjects = @checked;
	
	print "  Total accession provided: ".scalar @subjects.".\n";
	chomp(@subjects);
	
	if (!($queryID)){
		$queryID = shift @subjects;
		chomp $queryID;
		print "  NOTE: queryID not provided.\n        First accession (".$queryID.") was considered as query.\n";
	} else {
		print "  QueryID provided: ".$queryID.".\n";
		my @subjects2;
		my %removeDup;
		foreach my $key(@subjects){
			next if (exists $removeDup{$key});
			$removeDup{$key} = 1;
			push(@subjects2, $key) if ($key ne $queryID);
		}
		@subjects = @subjects2;
	}
	
	# check query info
	my $queryInfoRef = defineIdSubject(($queryID));
	mergeGeneralInfo($queryInfoRef);
	my @query = checkInfoTxid(($queryID));
	if (scalar @query == 0){
		die "\nERROR: Could not retrieve taxonomy id from query.\n";
	}
	
	my $sequenceInfoRef = retrieveSubjectInfo(($queryID));
	mergeGeneralInfo($sequenceInfoRef);
	if (!$generalInfo{$queryID}{"seq"}){
		die "\nERROR: Could not retrieve sequence from provided query ID.\n";
	}
	
	# fill Query info
	%queryInfo = %{$generalInfo{$queryID}};
	$txidMap = $queryInfo{"txid"} if (!$txidMap);
	
	print "Retrieving Subject info...\n";
	my $refDefinedID = defineIdSubject(@subjects);
	mergeGeneralInfo($refDefinedID);
		
	@subjects = checkInfoTxid(@subjects);
	#@subjects = queryOnTopList(@subjects);	
	
	# generate seq codes
	unshift(@subjects, $queryID);
	@subjects = generateCode(@subjects);

	# discard isoform
	if (!($showIsoform)){
		@subjects = discardIsoform(@subjects);
		#@new_subjects = @$newGiList;
		print "  Number of proteins after discarding isoforms: ".scalar @subjects."\n";
		if (scalar @subjects < 3){
			die "\nERROR: Less than 3 proteins with distinct geneID was retrieved.\n";
		}
	}
	
	&pair2pairLCA(keys %{$map_txid{"txids"}}); # fill %map_txid;
	
	@subjects = checkTaxLin(@subjects);
	# check query info
	if (!$map_txid{"txids"}{$generalInfo{$queryID}{"txid"}}){
		die "\nERROR: Could not retrieve taxonomy information from provided query ID.\n";
	}
	
	# tax filter
	@subjects = taxonomicFilters(@subjects);
	
	print "  Total number of proteins for phylogenetic analysis: ".scalar @subjects."\n";
	
	my %subjectList;
	foreach my $key(@subjects){
		$subjectList{$hashCode{"code"}{$key}{"id"}} = 1;
	}
	$sequenceInfoRef = retrieveSubjectInfo(keys %subjectList);
	mergeGeneralInfo($sequenceInfoRef);
	
	@subjects = checkSeq(@subjects);
	
	my $alignmentFile = &align($aligner, \@subjects);
	if (!($noTrimal)){
		$alignmentFile = &trimal($alignmentFile);
	}
	my $treeFile = &generateTree($alignmentFile);
	&formatTree($treeFile);
	print "All Done!\n";
	return 1;
	
}

sub querySeqFile {

	print "Fasta file provided: $querySeqFile\n";
	
	my $queryInfoRef = &formatQueryFile($querySeqFile); # fill %queryInfo;
	#mergeGeneralInfo($queryInfoRef);
	%queryInfo = %{$queryInfoRef};
	$queryID = $queryInfo{"name"};
	$generalInfo{$queryID} = {%queryInfo};
	#mergeGeneralInfo($queryInfoRef);
	
	my $blastResult = &executeBlast($local); # return Blast result;
	my $subjects = &formatBlastResult($blastResult); # return a list of subjects to be considered in the analysis
	my @subjects = @$subjects;
	
	print "Retrieving Subject info...\n";
	my $refDefinedID = defineIdSubject(@subjects);
	mergeGeneralInfo($refDefinedID);
	
	@subjects = checkInfoTxid(@subjects);
	
	if ($queryInfo{"txid"} eq "NULL"){
		if (exists $treeTableHash{$queryID}){
			$queryInfo{"txid"} = $treeTableHash{$queryID};
			$map_txid{"txids"}{$queryInfo{"txid"}} = {};
		} else {
			$queryInfo{"txid"} = $generalInfo{$subjects[0]}{"txid"};
		}
		$txidMap = $queryInfo{"txid"} if (!$txidMap);
		$generalInfo{$queryID}{"txid"} = $queryInfo{"txid"};
	}
	
	unshift (@subjects, $queryID);
	
	# generate seq codes
	@subjects = generateCode(@subjects);
	
	# discard isoform
	if (!($showIsoform)){
		@subjects = discardIsoform(@subjects);
		#@new_subjects = @$newGiList;
		print "  Number of proteins after discarding isoforms: ".scalar @subjects."\n";
		if (scalar @subjects < 3){
			die "\nERROR: Less than 3 proteins with distinct geneID was retrieved.\n";
		}
	}
	
	&pair2pairLCA(keys %{$map_txid{"txids"}}); # fill %map_txid;
	
	@subjects = checkTaxLin(@subjects);
	# check query info
	if (!$map_txid{"txids"}{$generalInfo{$queryID}{"txid"}}){
		die "\nERROR: Could not retrieve taxonomy information from provided query ID.\n";
	}

	# tax filter
	@subjects = taxonomicFilters(@subjects);
	
	if (scalar @subjects > $maxTarget){
		@subjects = splice(@subjects, 0, $maxTarget);
	}
	print "  Total number of proteins for phylogenetic analysis: ".scalar @subjects."\n";
		
	my %subjectList;
	my $queryCode = shift @subjects;
	foreach my $key(@subjects){
		$subjectList{$hashCode{"code"}{$key}{"id"}} = 1;
	}
	my $sequenceInfoRef = retrieveSubjectInfo(keys %subjectList);
	mergeGeneralInfo($sequenceInfoRef);

	unshift (@subjects, $queryCode);
	@subjects = checkSeq(@subjects);
	
	my $alignmentFile = &align($aligner, \@subjects);
	
	if (!($noTrimal)){
		$alignmentFile = &trimal($alignmentFile);
	}
	
	my $treeFile = &generateTree($alignmentFile);
	
	&formatTree($treeFile);
	print "All Done!\n";
	return 1;
}

sub queryMFastaFile {

	print "Alignment file provided: $queryAlignmentFile\n" if ($queryAlignmentFile);
	print "Multi FASTA file provided: $queryMFastaFile\n" if ($queryMFastaFile);
	
	my $file = $queryAlignmentFile if ($queryAlignmentFile);
	$file = $queryMFastaFile if ($queryMFastaFile);
	
	# extract alignment ID
	my ($ref_accessions, $ref_seq) = extractAlignment($file);
	my @accessions = @$ref_accessions;
	my @seq = @$ref_seq;
	
	if ($printLeaves){
		print "Printing names in ".$pid."_names.txt...\n";
		open (LEAVES, "> ".$pid."_names.txt");
		foreach my $leaves(@accessions){
			print LEAVES $leaves."\n";
		}
		close LEAVES;
		print "All done!\n";
		exit;
	}
	
	if (!($queryID)){
		$queryID = $accessions[0];
		chomp $queryID;
		print "  NOTE: queryID not provided.\n        First accession (".$queryID.") was considered as query.\n";
	} else {
		print "  QueryID provided: ".$queryID.".\n";
		my @subjects2;
		my @seq2;
		my $found;
		my $count = -1;
		my $querySeq;
		foreach my $key(@accessions){
			#my $header = $generalInfo{$key}{"fastaHeader"};
			$count++;
			if ($key eq $queryID) {
				if (!$found){
					$found = 1;
					$querySeq = $seq[$count];
					next;
				}
			}
			push(@subjects2, $key);
			push(@seq2, $seq[$count]);
		}
		@accessions = @subjects2;
		@seq = @seq2;
		if (!$found){
			die "\nERROR: QueryID provided is not in alignment file.\n";
		}
		unshift(@accessions, $queryID);
		unshift(@seq, $querySeq);
	}
	
	my ($ref_alignment, $ref_accessions2) = formatAlignment(\@accessions, \@seq, \%treeTableHash);
	mergeGeneralInfo($ref_alignment);
	
	@accessions = @$ref_accessions2;
	
	$queryID = $generalInfo{"ID1"}{"id"};
	#check query info	
	if (exists $treeTableHash{$queryID}){
		$generalInfo{"ID1"}{"txid"} = $treeTableHash{$queryID};
	} else {
		if ($generalInfo{"ID1"}{"type"} eq "other"){
			die "\nERROR: queryID provided do not have txid.\n";
		} else {
			my $refDefinedID = defineIdSubject(($queryID));
			if (exists $refDefinedID->{$queryID}->{"txid"}){
				$generalInfo{"ID1"}{"txid"} = $refDefinedID->{$queryID}->{"txid"};
			} else {
				die "\nERROR: could not retrieve txid from queryID ($queryID).\n";
			}
			
		}
	}
	
	$map_txid{"txids"}{$generalInfo{"ID1"}{"txid"}} = {};
	%queryInfo = %{$generalInfo{"ID1"}};
	$txidMap = $queryInfo{"txid"} if (!$txidMap);
	
	# Retrieve subjects data
	my @subjects;
	foreach my $key (@accessions){
		if ($generalInfo{$key}{"type"}){
			push(@subjects, $generalInfo{$key}{"id"});
		}
	}
	
	if (scalar @subjects > 0){
		my $refDefinedID = defineIdSubject(@subjects);
		#mergeGeneralInfo($refDefinedID);
		foreach my $key (@accessions){
			if (exists $refDefinedID->{$generalInfo{$key}{"id"}}){
				$generalInfo{$key}{"accession"} = $refDefinedID->{$generalInfo{$key}{"id"}}->{"accession"};
				$generalInfo{$key}{"geneID"} = $refDefinedID->{$generalInfo{$key}{"id"}}->{"geneID"};
				$generalInfo{$key}{"geneName"} = $refDefinedID->{$generalInfo{$key}{"id"}}->{"geneName"};
				$generalInfo{$key}{"txid"} = $refDefinedID->{$generalInfo{$key}{"id"}}->{"txid"};
				$generalInfo{$key}{"id"} = $refDefinedID->{$generalInfo{$key}{"id"}}->{"id"};
			}
		}
	}
	
	# Check txid data
	@subjects = checkInfoTxid(@accessions);
	
	# generate seq codes
	@subjects = generateCode(@subjects);
	
	# discard isoform
	if (!($showIsoform)){
		@subjects = discardIsoform(@subjects);
		#@new_subjects = @$newGiList;
		print "  Number of proteins after discarding isoforms: ".scalar @subjects."\n";
		if (scalar @subjects < 3){
			die "\nERROR: Less than 3 proteins with distinct geneID was retrieved.\n";
		}
	}
	
	&pair2pairLCA(keys %{$map_txid{"txids"}}); # fill %map_txid;
	
	@subjects = checkTaxLin(@subjects);
	# check query info
	if (!$map_txid{"txids"}{$generalInfo{"ID1"}{"txid"}}){
		die "\nERROR: Could not retrieve taxonomy lineage information from provided query ID.\n";
	}

	# tax filter
	@subjects = taxonomicFilters(@subjects);
	
	#print "  Checking sequence...\n";
	@subjects = checkSeq(@subjects);
	
	print "  Total number of proteins for phylogenetic analysis: ".scalar @subjects."\n";
	
	my $alignmentFile;
	if ($queryMFastaFile){
		$alignmentFile = &align($aligner, \@subjects);
	} else {
		$alignmentFile = $pid."_tmp_align.fasta";
		open (TMPALIGN, "> $alignmentFile") or die "\nERROR: Could not create an alignment file";
		foreach my $subject(@subjects){
			print TMPALIGN ">".$subject."\n".$generalInfo{$subject}{"seq"}."\n";
		}
	}
	
	if (!($noTrimal)){
		$alignmentFile = &trimal($alignmentFile);
	}
	
	my $treeFile = &generateTree($alignmentFile);
	
	&formatTree($treeFile);
	
	print "All Done!\n";
	return 1;

}

sub queryBlastFile {

	print "Blast file provided: $queryBlastFile\n";
	
	if (!($queryID)){
		print "NOTE: QueryID not provided.\n      Picking the first column of the blast result as QueryID.\n";
		open (BLASTTMP, "< $queryBlastFile") or die "\nERROR: Could not open $queryBlastFile.\n";
		my @blastTmp = <BLASTTMP>;
		close BLASTTMP;
		foreach my $blastLine(@blastTmp){
			my @line = split(/\t/, $blastLine);
			next if (scalar @line < 10);
			if ($line[0] =~ m/$delimiter/){
				my @line2 = split(/$delimiter/, $line[0]);
				$line[0] = $line2[$position];
			}
			$queryID = $line[0];
			my $type = verifyID($queryID);
			if (!$type && !exists $treeTableHash{$queryID}){
				print "NOTE: QueryID from the first column was not recognized as NCBI or Uniprot identifiers.\n";
				print "      QueryID from the first column was not provided in -treeTable.\n";
				print "      Picking the best hit of the blast result as QueryID.\n";
				my $bestHit = $line[1];
				if ($bestHit =~ /;/){
					my ($firstHit, @rest) = split(";", $bestHit);
					$bestHit = $firstHit;
				}
				if ($bestHit =~ m/$delimiter/){
					my @line2 = split(/$delimiter/, $bestHit);
					$bestHit = $line2[$position];
				}
				$queryID = $bestHit;
				my $type2 = verifyID($queryID);
				
				if (!$type2 && !exists $treeTableHash{$queryID}){
					die "\nERROR: Best hit of the blast result was not recognized as NCBI or Uniprot identifiers.\n       Please, check it or provide a table containing taxID for each accession using -taxTable.\n";
				}
			}
			last;
		}
	} 
	print "Query ID: ".$queryID."\n";
	
	# check query info
	my $queryInfoRef = defineIdSubject(($queryID));
	mergeGeneralInfo($queryInfoRef);
	my @query = checkInfoTxid(($queryID));
	if (scalar @query == 0){
		die "\nERROR: Could not retrieve taxonomy id from query.\n";
	}
	
	my $sequenceInfoRef = retrieveSubjectInfo(($queryID));
	mergeGeneralInfo($sequenceInfoRef);
	if (!$generalInfo{$queryID}{"seq"}){
		die "\nERROR: Could not retrieve sequence from provided query ID.\n";
	}
	
	# fill Query info
	%queryInfo = %{$generalInfo{$queryID}};
	$txidMap = $queryInfo{"txid"} if (!$txidMap);
	
	my $subjects = &formatBlastResult($queryBlastFile); # return a list of subjects to be considered in the analysis
	my @subjects = @$subjects;
	
	print "Retrieving Subject info...\n";
	my $refDefinedID = defineIdSubject(@subjects);
	mergeGeneralInfo($refDefinedID);
	
	@subjects = checkInfoTxid(@subjects);
	@subjects = queryOnTopList(@subjects);	
	# generate seq codes
	@subjects = generateCode(@subjects);
	
	# discard isoform
	if (!($showIsoform)){
		@subjects = discardIsoform(@subjects);
		#@new_subjects = @$newGiList;
		print "  Number of proteins after discarding isoforms: ".scalar @subjects."\n";
		if (scalar @subjects < 3){
			die "\nERROR: Less than 3 proteins with distinct geneID was retrieved.\n";
		}
	}
	
	&pair2pairLCA(keys %{$map_txid{"txids"}}); # fill %map_txid;
	
	@subjects = checkTaxLin(@subjects);
	# check query info
	if (!$map_txid{"txids"}{$generalInfo{$queryID}{"txid"}}){
		die "\nERROR: Could not retrieve taxonomy information from provided query ID.\n";
	}
	
	# tax filter
	@subjects = taxonomicFilters(@subjects);
	
	if (scalar @subjects > $maxTarget){
		@subjects = splice(@subjects, 0, $maxTarget);
	}
	print "  Total number of proteins for phylogenetic analysis: ".scalar @subjects."\n";
	
	my %subjectList;
	foreach my $key(@subjects){
		$subjectList{$hashCode{"code"}{$key}{"id"}} = 1;
	}
	$sequenceInfoRef = retrieveSubjectInfo(keys %subjectList);
	mergeGeneralInfo($sequenceInfoRef);
	
	@subjects = checkSeq(@subjects);
	
	my $alignmentFile = &align($aligner, \@subjects);
	if (!($noTrimal)){
		$alignmentFile = &trimal($alignmentFile);
	}
	my $treeFile = &generateTree($alignmentFile);
	&formatTree($treeFile);

	print "All Done!\n";
	return 1;

}

sub treeFile {

	print "Tree file provided: $treeFile\n";
	
	my $refLeavesTree = extractTreeLeaves($treeFile);
	my %leavesTree = %$refLeavesTree;
	
	if ($printLeaves){	
		print "Printing leaves in ".$pid."_names.txt...\n";
		open (LEAVES, "> ".$pid."_names.txt");
		print LEAVES join("\n", keys %leavesTree);
		close LEAVES;
		print "All done!\n";
		exit;
	}
	
	if (!($queryID)){
		die "\nERROR: Use -queryID and nominate a protein from your tree as query.\n";
	} 
	
	my ($refDefID, $tmpFile) = makeTempTree($treeFile, \%treeTableHash);
	mergeGeneralInfo($refDefID);
	
	# Retrieve subjects data
	my @accessions = keys %generalInfo;
	my @subjects;
	foreach my $key (@accessions){
		if ($generalInfo{$key}{"type"} ne "other"){
			push(@subjects, $generalInfo{$key}{"id"});
		}
	}
	
	if (scalar @subjects > 0){
		my $refDefinedID = defineIdSubject(@subjects);
		#mergeGeneralInfo($refDefinedID);
		foreach my $key (@accessions){
			if (exists $refDefinedID->{$generalInfo{$key}{"id"}}){
				$generalInfo{$key}{"accession"} = $refDefinedID->{$generalInfo{$key}{"id"}}->{"accession"};
				$generalInfo{$key}{"geneID"} = $refDefinedID->{$generalInfo{$key}{"id"}}->{"geneID"};
				$generalInfo{$key}{"geneName"} = $refDefinedID->{$generalInfo{$key}{"id"}}->{"geneName"};
				$generalInfo{$key}{"txid"} = $refDefinedID->{$generalInfo{$key}{"id"}}->{"txid"};
				$generalInfo{$key}{"id"} = $refDefinedID->{$generalInfo{$key}{"id"}}->{"id"};
			}
		}
	}
	
	# check query info;
	my @query = checkInfoTxid(("ID1"));
	if (scalar @query == 0){
		die "\nERROR: Could not retrieve taxonomy id from query.\n";
	}
	%queryInfo = %{$generalInfo{"ID1"}};
	$txidMap = $queryInfo{"txid"} if (!$txidMap);
	
	# Check txid data
	@subjects = checkInfoTxid(@accessions);	
	
	# sort accession by distance
	
	@subjects = orderByDistance($tmpFile);
	
	# generate seq codes
	@subjects = generateCode(@subjects);
	
	###########
	
	# discard isoform
	if (!($showIsoform)){
		@subjects = discardIsoform(@subjects);
		#@new_subjects = @$newGiList;
		print "  Number of proteins after discarding isoforms: ".scalar @subjects."\n";
		if (scalar @subjects < 3){
			die "\nERROR: Less than 3 proteins with distinct geneID was retrieved.\n";
		}
	}
	
	&pair2pairLCA(keys %{$map_txid{"txids"}}); # fill %map_txid;
	
	@subjects = checkTaxLin(@subjects);
	
	# check query info
	if (!$map_txid{"txids"}{$generalInfo{"ID1"}{"txid"}}){
		die "\nERROR: Could not retrieve taxonomy lineage information from provided query ID.\n";
	}

	# tax filter
	@subjects = taxonomicFilters(@subjects);
	
	###########
	
	my $treeFileTmp = &filterTree($tmpFile, \@subjects);
	
	&formatTree($treeFileTmp);
	system("rm $treeFileTmp");
	print "All Done!\n";
	return 1;

}
###################### subroutine ######################

sub incorporateTreeTable{

	foreach my $key(keys %generalInfo){
		if (exists $treeTableHash{$generalInfo{$key}{"name"}}){
			$generalInfo{$key}{"txid"} = $treeTableHash{$generalInfo{$key}{"name"}};
		}
	}
	return 1;
	
}

sub popOtherTableHash {

	my $file = $_[0];
	open (TABLE, "< $file") or die "\nERROR: Can't open the file $_\n";
	my @otherTable = <TABLE>;
	my @header;
	if ($otherTable[0] =~ m/^#/){
		my $header = shift @otherTable;
		chomp $header;
		@header = split(/\t/, $header);
	} 		
	foreach my $line (@otherTable){
		my $error2 = 0;
		chomp $line;
		$line =~ s/\r//g;
		next if ($line eq "");
		my @line = split(/\t/, $line);
		my $leafID = shift @line;
		#if (exists $leavesTree{$leafID}){
		#	print "NOTE: your tree does not contain $leafID\n";
		#} else {
		my $count = 1;
		foreach my $line2 (@line){
			my $label;
			if (!$header[$count]){
				$label = "feature".$count;
			} else {
				$label = $header[$count];
			}
			$otherTableHash{$label}{$leafID} = $line2;
			$count++;
		}
		#}
	}
	close TABLE;
	return 1;
	
}

sub popTreeTableHash {
	my $file = $_[0];

	open (TABLE, "< $file") or die "\nERROR: Can't open the file $_\n";
	while (my $line = <TABLE>){
		my $error2 = 0;
		chomp $line;
		$line =~ s/\r//g;
		next if ($line eq "");
		my @line = split(/\t/, $line);
		
		if ($line[1] =~ /\D/){
			print "NOTE: txid provided for $line[0] contains a not number character. This information was ignored.\n";
			$error2 = 1;
		}
		$treeTableHash{$line[0]} = $line[1] if ($error2 == 0);
	}
	close TABLE;
	return 1;
	
}

sub taxonomicFilters {
	my @subjects = @_;
	
	if ($restrictTax){
		@subjects = &restrictTax(\@subjects, \%restrictTax);
		print "  number of proteins after restricting with Taxonomy ID provided: ".scalar @subjects."\n";
		if (scalar @subjects < 3){
			die "\nERROR: Less than 3 proteins was retrieved after restricting with Taxonomy ID provided.\n";
		}
	}
	
	if ($taxFilter){
		@subjects = &taxFilter(\@subjects, $taxFilter, $taxFilterCat);
		print "  number of proteins after applying taxonomic filter: ".scalar @subjects."\n";
		if (scalar @subjects < 3){
			die "\nERROR: Less than 3 proteins was retrieved after applying taxonomic filter.\n";
		}
	}
	
	if ($lcaLimit > 0){
		@subjects = &lcaFilter($lcaLimit, \@subjects);
		print "  number of proteins after applying LCA filter: ".scalar @subjects."\n";
		if (scalar @subjects < 3){
			die "\nERROR: Less than 3 proteins was retrieved after applying LCA filter.\n";
		}
	}
	
	if ($lcaLimitDown > 0){
		@subjects = &lcaFilterDown($lcaLimitDown, \@subjects);
		print "  number of proteins after applying LCA filter: ".scalar @subjects."\n";
		if (scalar @subjects < 3){
			die "\nERROR: Less than 3 proteins was retrieved after applying LCA filter.\n";
		}
	}
	
	return @subjects;
	
}

sub orderByDistance {
	my $treeFile2 = $_[0];
	
	my $input = new Bio::TreeIO(-file   => $treeFile2,
								-format => "newick");
								
	my $tree = $input -> next_tree;
	my @leaves = $tree -> get_leaf_nodes();
	
	my $queryCode = "ID1";
	my $n1 = $tree->find_node($queryCode);
	my %distance;
	foreach my $node(@leaves) {
		my $results = $tree->distance(-nodes=> [$n1, $node]);
		my $node2 = $node->id;
		next if ($node2 eq "ID1");
		$distance{$node2} = $results;
	}
	
	my @accession = sort {$distance{$a} <=> $distance{$b}} (keys %distance);
	unshift (@accession, "ID1");
	return @accession;
}

sub translateFastaFile {
	
	my $file = $_[0];
	
	open(FILE, "< $file") or die "\nERROR: Could not open $file.\n";
	my @fileContent;
	
	while (my $line = <FILE>){
		chomp $line;
		if ($line =~ /^>/){
			$line =~ /(ID\d+)/;
			my $id = $hashCode{"code"}{$1}{"id"};
			push(@fileContent, ">".$generalInfo{$id}{"name"}."\n");
		} else {
			push(@fileContent, $line."\n");
		}		
	}
	
	close FILE;
	open(NEW, "> $file") or die "\nERROR: Could not create $file.\n";
	print NEW join("", @fileContent);
	close NEW;
	
	return 1;
}

sub generateCode {
	my @list = @_;
	my @newList;
	
	my $count = 1;
	foreach my $id(@list){
		my $id2 = "ID".$count;
		$hashCode{"code"}{$id2}{"id"} = $id;
		$hashCode{"code"}{$id2}{"txid"} = $generalInfo{$id}{"txid"};
		$hashCode{"id"}{$id}{$id2} = 1;
		push(@newList, $id2);
		$count++;
	}
	return @newList;
}

sub checkSeq {
	my @list = @_;
	my @newList;
	print "  Checking sequence data...  ";
	my $note = 0;
	foreach my $key(@list){
		my $subject = $hashCode{"code"}{$key}{"id"};
		if (!exists $generalInfo{$subject}{"seq"}){
			print "\n    NOTE: Could not retrieve sequence from $key. This entry will be discarded.";
			$note = 1;
		} else {
			push (@newList, $key);
		}
	}
	if (scalar @newList < 3){
		die "\nERROR: less than 3 proteins had their sequence retrieved.";
	}
	
	if ($note == 0){
		print "OK!\n";
	} else {
		print "\n";
	}
	
	return @newList;
}

sub checkTaxLin {
	my @list = @_;
	my @newList;
	print "    Checking taxonomy lineage data...  ";
	my $note = 0;
	foreach my $key(@list){
		my $subject = $hashCode{"code"}{$key}{"txid"};
		if (!exists $map_txid{"txids"}{$subject}){
			if ($forceNoTxid){
				print "\n      NOTE: Could not retrieve txid lineage from $key. It was set to root lineage.";
				$note = 1;
				push(@newList, $key);
				$generalInfo{$subject}{"txid"} = 1;
				$hashCode{"code"}{$key}{"txid"} = 1
			} else {
				print "\n      NOTE: Could not retrieve txid lineage from $key. This entry will be discarded.";
				$note = 1;
			}
		} else {
			push (@newList, $key);
		}
	}
	if($note == 0){
		print "OK!\n";
	} else {
		print "\n";
	}
	
	return @newList;
}

sub checkInfoTxid {
	my @list = @_;
	my @newList;
	print "  Checking taxonomy data...  ";
	my $note = 0;
	foreach my $key(@list){
		if (exists $generalInfo{$key} && exists $generalInfo{$key}{"name"} && exists $treeTableHash{$generalInfo{$key}{"name"}}){
			# Incorporate treeTableHash data
			push(@newList, $key);
			$generalInfo{$key}{"txid"} = $treeTableHash{$generalInfo{$key}{"name"}};
			$map_txid{"txids"}{$generalInfo{$key}{"txid"}} = {};
		} else {
			if (exists $generalInfo{$key} && exists $generalInfo{$key}{"txid"}){
				push(@newList, $key);
				$map_txid{"txids"}{$generalInfo{$key}{"txid"}} = {};
			} else {
				my $name;
				if (exists $generalInfo{$key} && $generalInfo{$key}{"name"}){
					$name = $generalInfo{$key}{"name"};
				} else {
					$name = $key;
				}
				if ($forceNoTxid){
					print "\n    NOTE: Could not retrieve txid from ".$name.". It was set to 1.";
					push(@newList, $key);
					$generalInfo{$key}{"txid"} = 1;
					$note = 1;
				} else {
					print "\n    NOTE: Could not retrieve txid from ".$name.". This entry will be discarded.";
					$note = 1;
				}
			}
		}		
	}
	if ($note == 0){
		print "OK!\n";
	} else {
		print "\n";
	}
	return @newList;
}

sub queryOnTopList {
	my @list = @_;
	my @newList;
	my %queryInfo2;
	my $queryOriginal = $queryInfo{"name"};
	$queryInfo2{$queryOriginal} = 1;
	if (!$querySeqFile){
		$queryInfo2{$generalInfo{$queryOriginal}{"id"}} = 1;
		$queryInfo2{$generalInfo{$queryOriginal}{"accession"}} = 1;
		my $queryIDOriginal = $generalInfo{$queryOriginal}{"id"};
		$queryIDOriginal =~ s/\.\d+//;
		$queryInfo2{$queryOriginal} = 1;
	}
	
	foreach my $key(@list){
		if (!exists $queryInfo2{$key}){
			push(@newList, $key);
		}
	}
	unshift (@newList, $queryOriginal);
	return @newList;
}

sub mergeGeneralInfo {
	my $refHash = $_[0];
	my %deRefHash = %$refHash;
	foreach my $key(keys %deRefHash){
		if (exists $generalInfo{$key}){
			@{$generalInfo{$key}}{keys %{$deRefHash{$key}}} = values %{$deRefHash{$key}};
		} else {
			$generalInfo{$key} = ();
			@{$generalInfo{$key}}{keys %{$deRefHash{$key}}} = values %{$deRefHash{$key}};
		}
	}
}

sub restrictTax {
	my $giList = $_[0];
	my $restrictTaxRef = $_[1]; 
	my @giList = @$giList;
	my %restrictTax2 = %$restrictTaxRef;
	my @newGiList;
	
	foreach my $gi (@giList){
		my $subject = $hashCode{"code"}{$gi}{"id"};
		my $subjectTxid2 = $generalInfo{$subject}{"txid"};
		if (exists $restrictTax2{$subjectTxid2}){
			push(@newGiList, $gi);
		} else {
			next;
		}
	}
	return @newGiList;
}

sub lcaFilter {
	my $lcaLimit2 = $_[0];
	my $refsubjects = $_[1];
	my @subjects2 = @$refsubjects;
	my @newSubjects;
	foreach my $subject2(@subjects2){
		my $subject = $hashCode{"code"}{$subject2}{"id"};
		my $lcaSubject = $map_txid{"pair2pairLCA"}{$generalInfo{$subject}{"txid"}}{"lcaN"}{$txidMap};
		if ($lcaLimit2 <= $lcaSubject){
			push (@newSubjects, $subject2);
		}
	}
	return @newSubjects;
}

sub lcaFilterDown {
	my $lcaLimit2 = $_[0];
	my $refsubjects = $_[1];
	my @subjects2 = @$refsubjects;
	my @newSubjects;
	foreach my $subject2(@subjects2){
		my $subject = $hashCode{"code"}{$subject2}{"id"};
		my $lcaSubject = $map_txid{"pair2pairLCA"}{$generalInfo{$subject}{"txid"}}{"lcaN"}{$txidMap};
		if ($lcaLimit2 >= $lcaSubject || $subject2 eq "ID1"){
			push (@newSubjects, $subject2);
		}
	}
	return @newSubjects;
}

sub taxFilter {
	my $giList = $_[0];
	my $taxFilter2 = $_[1];
	my $taxFilterCat2 = $_[2];
	
	my @giList = @$giList;
	my @newGiList;
	
	my %filterTax; 	# $filterTax{"clade"}
					# $filterTax{"txid"}
	
	my $queryTxid2 = $queryInfo{"txid"};
	$filterTax{"txid"}{$queryTxid2} = 1;	
	
	if ($taxFilterCat2 ne "lca"){
		my @taxSimple_ranks = (
			"superkingdom",
			"kingdom",
			"phylum",
			"subphylum",
			"superclass",
			"class",
			"subclass",
			"superorder",
			"order",
			"suborder",
			"superfamily",
			"family",
			"subfamily",
			"genus",
			"subgenus",
			"species",
			"subspecies",
		);
		
		my $taxonCode;
		for(my $i = 0; $i < scalar @taxSimple_ranks; $i++){
			if ($taxFilterCat2 eq $taxSimple_ranks[$i]){
				$taxonCode = $i+1;
				last;
			}
		}
		
		my @queryLineage = @{$map_txid{"txids"}{$queryTxid2}{"lineageTaxSimpleN"}};
		my $queryClade = $queryLineage[$taxonCode];
		$filterTax{"clade"}{$queryClade} = 1;
		
		foreach my $gi (@giList){
			my $subject = $hashCode{"code"}{$gi}{"id"};
			my $subjectTxid2 = $generalInfo{$subject}{"txid"};
			if (exists $filterTax{"txid"}{$subjectTxid2}){
				push(@newGiList, $gi);
				next;
			} else {
				my @subjectLineage = @{$map_txid{"txids"}{$subjectTxid2}{"lineageTaxSimpleN"}};
				my $subjectClade = $subjectLineage[$taxonCode];
				
				if (!exists $filterTax{"clade"}{$subjectClade}){
					$filterTax{"clade"}{$subjectClade} = 1;
					$filterTax{"txid"}{$subjectTxid2} = 1;
					push(@newGiList, $gi);
				} else {
					if ($filterTax{"clade"}{$subjectClade} < $taxFilter2){
						$filterTax{"clade"}{$subjectClade} += 1;
						$filterTax{"txid"}{$subjectTxid2} = 1;
						push(@newGiList, $gi);
					} else {
						next;
					}
				}
			}
		}
	} else {
	
		my $lca = $map_txid{"pair2pairLCA"}{$queryTxid2}{"lcaN"}{$queryTxid2};
		$filterTax{"clade"}{$lca} = 1;
		
		foreach my $gi (@giList){
			my $subject = $hashCode{"code"}{$gi}{"id"};
			my $subjectTxid2 = $generalInfo{$subject}{"txid"};
			if (exists $filterTax{"txid"}{$subjectTxid2}){
				push(@newGiList, $gi);
				next;
			} else {
				my $subjectClade = $map_txid{"pair2pairLCA"}{$queryTxid2}{"lcaN"}{$subjectTxid2};
				
				if (!exists $filterTax{"clade"}{$subjectClade}){
					$filterTax{"clade"}{$subjectClade} = 1;
					$filterTax{"txid"}{$subjectTxid2} = 1;
					push(@newGiList, $gi);
				} else {
					if ($filterTax{"clade"}{$subjectClade} < $taxFilter2){
						$filterTax{"clade"}{$subjectClade} += 1;
						$filterTax{"txid"}{$subjectTxid2} = 1;
						push(@newGiList, $gi);
					} else {
						next;
					}
				}
			}
		}
	}
	

	return (@newGiList);
}

sub checkSoftware {
	my $softwareName = $_[0];
	my $paths = $_[1];
	my $defPath;
	my $control = 0;
	
	if ($paths ne ""){
		my @paths = split(":", $paths);
		foreach my $path2(@paths){
			$path2 =~ s/\/$//;
			next if ($path2 =~ m/^$/);
			my $path = $path2."/".$softwareName;
			if (-e $path && -x _){
				$defPath = $path;
				$control = 1;
				last;
			}
		}
	}
	
	if ($control == 0){
		my $whichSoftware = which($softwareName);
		if ($whichSoftware){
			$defPath = $softwareName;
		} else {
			die "\nERROR: Can't locate $softwareName...\n";
		}
	}
	
	return $defPath;
}

sub extractAlignment {
	
	my $alignment = $_[0];	
	#my $refTreeTable = $_[1];	
	#my %treeTable = %$refTreeTable;
	my @accessions;
	my @seq;
	open (ALIGN, "< $alignment") or die "\nERROR: Could not open the alignment file.\n";
	my $oldDelimiter = $/;
	$/ = "\n>";
	my %hash_align;
	my $seq_length = 0;
	my $error;
	my $idType;
	my $count = 0;
	while (my $line = <ALIGN>){
		chomp $line;
		next if ($line =~ /^[\n\r]*$/);
		$line =~ s/^>//g;
		my ($header, $seq) = split(/\n/, $line, 2);
		$seq =~ s/\n//g;
		if ($header =~ m/ /){
			$header = substr($header, 0, index($header, " "));
		}
		
		$accessions[$count] = $header;
		$seq[$count] = $seq;
		$count++;
		
		if ($seq_length == 0){
			$seq_length = length $seq;
		} else {
			if ($queryAlignmentFile){
				if ($seq_length != length $seq){
					die "\nERROR: There are sequences with different length.\n";
				}
			}
		}
		#print TMPALIGN ">".$header."\n".$seq."\n";
	}
	$/ = $oldDelimiter;
	return (\@accessions, \@seq);
}

sub formatAlignment {
	my $refAccession = $_[0];
	my $refSeq = $_[1];
	my $treeTable = $_[2];
	my %hash_align;
	my @defAccession;
	my $error;
	
	my @accessions = @$refAccession;
	my @seq = @$refSeq;
	
	my $count = 1;
	for(my $i = 0; $i < scalar @accessions; $i++){
		my $header = $accessions[$i];
		my $seq = $seq[$i];
		
		my @id = $header =~ m/$delimiter/;
		my $nDelimiter = @id;
		my $defID;
		if ($nDelimiter > 0){
			my @splitLeaf = split(/$delimiter/, $header);
			$defID = $splitLeaf[$position];
		} else {
			$defID = $header;
		}
		my $idType = verifyID($defID);
		if (!$idType){
			if (!exists $treeTable->{$header}){
				if (!$forceNoTxid){
					$error = 1;
					print "NOTE: Could not recognize $defID as NCBI or Uniprot identifier.\n      Could not find $defID in the table.\n      Please check it.\n";
				}
			}
			$idType = "other";
		}
		my $id = "ID".$count;
		$hash_align{$id}{"name"} = $header;
		$hash_align{$id}{"fastaHeader"} = $header;
		$hash_align{$id}{"id"} = $defID;
		$hash_align{$id}{"accession"} = $defID;
		$hash_align{$id}{"seq"} = $seq;
		$hash_align{$id}{"type"} = $idType;
		$hash_align{$id}{"geneID"} = "NULL";
		$hash_align{$id}{"geneName"} = "NULL";
		
		push(@defAccession, $id);
		$count++;
	}
	
	if ($error){
		die "\nERROR: Some sequences were not recognised to have NCBI or Uniprot identifier...\n";
	}
	return (\%hash_align, \@defAccession);
}

sub makeTempTree {
	my $treeFile2 = $_[0];
	my $treeTable = $_[1];
	
	my $input = new Bio::TreeIO(-file   => $treeFile2,
								-format => $treeFormat);
	my $tree = $input -> next_tree;
	my @leaves = $tree -> get_leaf_nodes();
	
	my %hash_leaf;
	my $count = 2;
	my $error;
	my $queryFound;
	
	foreach my $leaves (@leaves){
		my $id = $leaves->id;
		if ($id =~ m/ /){
			$id = substr($id, 0, index($id, " "));
		}
		
		my $code;
		if ($id eq $queryID and !$queryFound){
			$queryFound = 1;
			$code = "ID1";
		} else {
			$code = "ID".$count;
			$count++;
		}
		
		$leaves->id($code);
		my @id = $id =~ m/$delimiter/;
		my $nDelimiter = @id;
		my $defID;
		if ($nDelimiter > 0){
			my @splitLeaf = split(/$delimiter/, $id);
			$defID = $splitLeaf[$position];
		} else {
			$defID = $id;
		}
		my $idType = &verifyID($defID);
		if ($idType){
			if ($defID =~ m/-/){
				$defID = substr($defID, 0, index($defID, "-"));
			}
			#push(@accessions, $defID);
		} else {
			$idType = "other";
			if (!exists $treeTable->{$id}){
				if (!$forceNoTxid){
					$error = 1;
					print "NOTE: Could not recognize $defID as NCBI or Uniprot identifier.\n      Could not find $defID in the table.\n      Please check it.\n";
				}
			}
		}
		$hash_leaf{$code}{"name"} = $id;
		$hash_leaf{$code}{"id"} = $defID;
		$hash_leaf{$code}{"geneID"} = "NULL";
		$hash_leaf{$code}{"geneName"} = "NULL";
		$hash_leaf{$code}{"accession"} = $defID;
		$hash_leaf{$code}{"type"} = $idType;
	}
	if ($error){
		die "\nERROR: Some leaves were not recognised to have NCBI or Uniprot identifier...\n";
	}
	if (!$queryFound){
		die "\nERROR: The queryID provided was not found in the tree...\n";
	}
	
	my $tmpTree = $pid."_tmp_seq_tree.nwk";
	my $output = Bio::TreeIO -> new(-format => "newick",
									-file => "> ".$tmpTree);
	$output -> write_tree($tree);
	
	return (\%hash_leaf, $tmpTree);
}

sub filterTree {
	my $treeFile2 = $_[0];
	my $remLeafs = $_[1];
	my @new_subjects = @$remLeafs;
	my %remLeafs = map { $_ => 1 } @new_subjects;
	
	my $input = new Bio::TreeIO(-file   => $treeFile2,
								-format => "newick");
	my $tree = $input -> next_tree;
	
	my @leaves = $tree -> get_leaf_nodes();
	
	foreach my $leaves (@leaves){
		my $id = $leaves->id;
		my @id2 = keys %{$hashCode{"id"}{$id}};
		if (!exists $remLeafs{$id2[0]}){
			my $ancestor = $leaves->ancestor;
			$tree->remove_Node($leaves);
			my @descendent = $ancestor->each_Descendent;
			while(scalar @descendent == 0){
				my $newAncestor = $ancestor->ancestor;
				$tree->remove_Node($ancestor);
				$ancestor = $newAncestor;
				@descendent = $ancestor->each_Descendent;
			}
		}
		$leaves->id($id2[0])
	}
	
	$tree->contract_linear_paths(1);
	print "  Total number of proteins for phylogenetic analysis: ".scalar @new_subjects."\n";
	
	my $tmpTree = $pid."_tmp_seq_tree.nwk";
	my $output = Bio::TreeIO -> new(-format => "newick",
									-file => "> ".$tmpTree);
	$output -> write_tree($tree);
	return $tmpTree;
}

sub extractTreeLeaves {
	my $treeFile2 = $_[0];
	my $input = new Bio::TreeIO(-file   => $treeFile2,
								-format => $treeFormat);
	my $tree = $input -> next_tree;
	
	my @leaves = $tree -> get_leaf_nodes();
	my %leaves;
	foreach my $leaves (@leaves){
		my $id = $leaves->id;
		if ($id =~ m/ /){
			$id = substr($id, 0, index($id, " "));
		}
		$leaves{$id} = {};
	}
	return \%leaves;
}

sub extractLeavesId {
	my $refLeaves = $_[0];
	my $treeTable = $_[1];
	my %treeTable = %$treeTable;
	
	my @leaves = @$refLeaves;
	my @accessions;
	my %idList;
	my $error = 0;
	foreach my $id (@leaves){
		my @id = $id =~ m/$delimiter/;
		my $nDelimiter = @id;
		my $defID;
		if ($nDelimiter > 0){
			my @splitLeaf = split(/$delimiter/, $id);
			
			$defID = $splitLeaf[$position];
		} else {
			$defID = $id;
		}
		my $idType = &verifyID($defID);
		if ($idType){
			if ($defID =~ m/-/){
				$defID = substr($defID, 0, index($defID, "-"));
			}
			push(@accessions, $defID);
		} else {
			$idType = "NULL";
			if (!exists $treeTable{$id}){
				if (!$forceNoTxid){
					$error = 1;
					print "NOTE: Could not recognize $defID as NCBI or Uniprot identifier.\n      Could not find $defID in the table.\n      Please check it.\n";
				}
			}
		}
		$idList{$id}{"name"} = $id;
		$idList{$id}{"id"} = $defID;
		$idList{$id}{"geneID"} = "NULL";
		$idList{$id}{"geneName"} = "NULL";
		$idList{$id}{"accession"} = $defID;
		$idList{$id}{"type"} = $idType;
	}
	if ($error == 1){
		die "\nERROR: Some leaves were not recognised to have NCBI or Uniprot identifier...\n";
	}
	return (\@accessions, \%idList);
}

sub formatQueryFile {
	
	my $inputFile = $_[0];
	my $query = do {
		local $/ = undef;
		open my $fh, "<", $inputFile or die "\nERROR: could not open $inputFile: $!";
		<$fh>;
	};
	
	my %defID;
	
	$query =~ s/^[^>]+//;
	my @sequence = split(/\n>/, $query);
	
	#verify if it's a FASTA format file and if it contain a single sequence;
	die "\nERROR: Sequence is not in FASTA format or the file is a multi-FASTA.\n" 
		if (scalar @sequence > 2);

	#Extract query information;

	my ($queryHeader, $queryID, $querySeq, $queryTax2);

	my $queryFasta = $sequence[0];
	$queryFasta =~ s/^>//;
	$queryFasta =~ s/\r//g;
	$queryHeader = substr($queryFasta, 0, index($queryFasta, "\n"));
	
	if ($queryHeader =~ m/ /){
		$queryID = substr($queryHeader, 0, index($queryHeader, " "));
	} else {
		$queryID = $queryHeader;
	}
	$queryID =~ s/[^\w.-]/_/g;
	$querySeq = substr($queryFasta, index($queryFasta, "\n")+ 1);
	$queryID = "Q_".$queryID;
	
	$defID{"name"} = $queryID;
	$defID{"type"} = "fasta";
	$defID{"seq"} = $querySeq;
	$defID{"id"} = $queryID;
	#$defID{"fastaHeader"} = $queryID;
	$defID{"accession"} = $queryID;
	$defID{"txid"} = "NULL";
	$defID{"geneID"} = "NULL";
	$defID{"geneName"} = "NULL";
	$defID{"qlen"} = length $querySeq;
	
	if ($queryHeader =~ /taxid=\[(\w+)\]/){
		$queryTax2 = $1;
		if ($queryTax2 =~ /\D/){
			undef $queryTax2;
			print "taxid provided is not a valid number. Ignoring it...\n";
		} else {
			print "Query taxid: $queryTax2\n";
			$defID{"txid"} = $queryTax2;
			$map_txid{"txids"}{$defID{"txid"}} = {};
			$txidMap = $defID{"txid"} if (!$txidMap);
		}
	} else {
		if (!($queryTax)){
			print "taxid not provided. Setting the taxid of the BLAST besthit to the query.\n";
		} else {
			print "Query taxid: $queryTax\n";
			$queryTax2 = $queryTax;
			$defID{"txid"} = $queryTax2;
			$map_txid{"txids"}{$defID{"txid"}} = {};
			$txidMap = $defID{"txid"} if (!$txidMap);
		}
	}
	return \%defID;
}

sub retrieveInfoUniprot {
	my $refuniprotlist = $_[0];
	my $type = $_[1];
	my @uniprotlist = @$refuniprotlist;
	my %uniprotData;
	my $typeRetrieve;
	my $posRetrieve;
	my $delimiter2;
	if ($type eq "accession"){
		$posRetrieve = 1;
	} elsif ($type eq "mnemonic") {
		$posRetrieve = 2;
	} elsif ($type eq "accessioniso") {
		$posRetrieve = 1;
	} else {
		return 0;
	}
	$delimiter2 = quotemeta ("|");
	# retrieve seq
	
	my $retrieveWeb = 1;
	my $fetch_fasta;
	
	if ($type eq "accession" or $type eq "mnemonic"){
		my $http = HTTP::Tiny->new(agent => "libwww-perl $email");
		my $n = -1;
		my $m = -50;
		do {
			$n = $n + 50;
			$m = $m + 50;
			$n = $#uniprotlist if ($n > $#uniprotlist);
			my $url_fetch_seq = "http://www.uniprot.org/uniprot/?query=$type:".join("+OR+$type:",@uniprotlist[$m .. $n])."&force=yes&format=fasta";
			my $response = $http->get($url_fetch_seq);
			$fetch_fasta .= $response->{content};
			sleep 1;
		} while ($n < $#uniprotlist);
		
	} elsif ($type eq "accessioniso") {
		my $http = HTTP::Tiny->new(agent => "libwww-perl $email");
		foreach my $id (@uniprotlist){
			my $url_fetch_seq = "http://www.uniprot.org/uniprot/$id".".fasta";
			my $response = $http->get($url_fetch_seq);
			$fetch_fasta .= $response->{content};
			sleep 1;
		}
		
	}
	
	if ($fetch_fasta){
		my @fetch_fasta = split("\n>", $fetch_fasta);
		for(my $i = 0; $i < scalar @fetch_fasta; $i++){
			my ($tempfastaHeader, $fastaSeq) = split(/\n/, $fetch_fasta[$i], 2);
			my ($fastaHeader, $rest) = split(" ", $tempfastaHeader, 2);
			$fastaHeader =~ s/>//g;
			my @fastaHeader = split(/$delimiter2/, $fastaHeader); ## delimiter, pos
			my $fastaID = $fastaHeader[$posRetrieve];
			$fastaSeq =~ s/\n//g;
			$uniprotData{$fastaID}{"seq"} = $fastaSeq;
			#$uniprotData{$fastaID}{"fastaHeader"} = $fastaHeader;
		}
	}
	
	return \%uniprotData;

}

sub retrieveInfoNCBI {

	my ($refrefseqlist) = @_;
	my @refseqlist = @$refrefseqlist;
	my %refseqData;
	#my %refseqDataHeader;
	my %accession2gi;
	my %gi2accession;
	
	my $n = -1;
	my $m = -50;
	
	do {
		$n = $n + 50;
		$m = $m + 50;
		$n = $#refseqlist if ($n > $#refseqlist);
		
		my $url_fetch_id = "https://www.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?tool=taxontree&email=$email&db=protein&retmode=text&rettype=seqid&id=".join(",",@refseqlist[$m .. $n]);
		my $fetch_lineage2;
		my $errorCount2 = -1;
		do {
			my $response = HTTP::Tiny->new->get($url_fetch_id);
			$fetch_lineage2 = $response->{content};
			$errorCount2++;
			sleep 1;
		} while ($fetch_lineage2 =~ m/<\/ERROR>|<\/Error>|<title>Bad Gateway!<\/title>|<title>Service unavailable!<\/title>|Error occurred:/ and $errorCount2 < 5);
		if ($errorCount2 > 4){
			die "\nERROR: Sorry, access to NCBI server retrieved error 4 times. Please, try to run TaxOnTree again later.";
		}
		
		my @ids = split(/\n\n/, $fetch_lineage2);
		foreach my $ids (@ids){
			$ids =~ /accession \"([^\" ]+)\" ,/;
			my $acc = $1;
			$ids =~  /version (\d+) /;
			my $ver = $1;
			$ids =~  /Seq-id ::= gi (\d+)/;
			my $gi = $1;
			if ($gi && $acc){
				$accession2gi{$gi} = $acc.".".$ver;
				$gi2accession{$acc.".".$ver} = $gi;
			}
			
		}
		
		my $url_fetch_seq = "https://www.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?tool=taxontree&email=$email&db=protein&retmode=xml&rettype=fasta&id=".join(",",@refseqlist[$m .. $n]);
		my $fetch_lineage;
		my $errorCount = -1;
		do {
			my $response = HTTP::Tiny->new->get($url_fetch_seq);
			$fetch_lineage = $response->{content};
			$errorCount++;
			sleep 1;
		} while ($fetch_lineage =~ m/<\/Error>|<title>Bad Gateway!<\/title>|<title>Service unavailable!<\/title>|Error occurred:/ and $errorCount < 5);
		if ($errorCount > 4){
			die "\nERROR: Sorry, access to NCBI server retrieved error 4 times. Please, try to run TaxOnTree again later.";
		}
		my $xs2 = XML::Simple->new();
		my $doc_lineage = $xs2->XMLin($fetch_lineage, ForceArray => ["TSeq"]);
		
		my @linkSet = @{$doc_lineage->{"TSeq"}};
				
		foreach my $link(@linkSet){
		
			#my $gi = $link->{"TSeq_gi"} if ($link->{"TSeq_gi"});
			my $accession = $link->{"TSeq_accver"};
			my $seq = $link->{"TSeq_sequence"};
			#$refseqData{$accession}{"seq"} = $seq;
			$accession =~ /\.(\d+)$/;
			my $version = $1;
			$accession =~ s/\.\d+//;
			#$refseqData{$accession}{"seq"} = $seq;
			#$refseqData{$gi2accession{$accession}}{"seq"} = $seq if (exists $gi2accession{$accession});
			#$refseqDataHeader{$accession}{"fastaHeader"} = "gi\|".$gi."\|ref\|".$accession."\|";

			$refseqData{$accession}{"v"}{$version}{"seq"} = $seq;
			if (exists $gi2accession{$accession.".".$version}){
				my $gi = $gi2accession{$accession.".".$version};
				$refseqData{$gi}{"seq"} = $seq;
			} 
			
			if (exists $refseqData{$accession}{"vmax"}){
				$refseqData{$accession}{"vmax"} = $version if ($version > $refseqData{$accession}{"vmax"});
			} else {
				$refseqData{$accession}{"vmax"} = $version;
			}
			
			
		}
			
		sleep 1;
			
	} while ($n < $#refseqlist);

	return \%refseqData;

}	

sub executeBlast {
	
	my $blast_result;
	if (!$local){
		if (!$internetConnection){
			die "\nERROR: Web BLAST requested, but no internet connection.\n";
		}
		my $encoded_query = uri_escape(">".$queryInfo{"name"}."\n".$queryInfo{"seq"});
		print "Executing BLAST search on NCBI server...\n  Database: $database\n  BLAST evalue: $evalue\n";
		$blast_result = webBLAST($blastProgram, $database, $maxTargetBlast, $encoded_query, $evalue);
		print "  Done!\n";
	} else {
		open(OUT, "> ".$pid."_seq.fasta") or die "\nERROR: Can't create a query file.\n";
		print OUT ">".$queryInfo{"name"}."\n".$queryInfo{"seq"};
		close OUT;
		my $queryBlastInput = $pid."_seq.fasta";
		print "Executing local BLAST search...\n  Database: $database\n  BLAST evalue: $evalue\n";
		$blast_result = localBlast($blastProgram, $database, $maxTargetBlast, $queryBlastInput, $evalue);
		print "  Done!\n";
	}
	return $blast_result;
}

sub webBLAST {

	# BLAST search using NCBI server and protein sequence database.
	# This portion of the code was written based on a sample script
	# available in http://www.ncbi.nlm.nih.gov/blast/docs/web_blast.pl
	
	my ($program, $database, $defMaxTarget, $encoded_query, $evalue) = @_;

	print "  BLAST max target sequences: $defMaxTarget\n";
	my $ua = HTTP::Tiny->new;
	
	# build the request
	my $args = "CMD=Put&TOOL=taxontree&EMAIL=$email&PROGRAM=$blastProgram&DATABASE=$database&HITLIST_SIZE=$defMaxTarget&EXPECT=$evalue&QUERY=" . $encoded_query;
	my $url = 'https://www.ncbi.nlm.nih.gov/blast/Blast.cgi';
	
	# get the response
	my $response = $ua->request('POST', $url, { content => $args,
												headers => { 'content-type' => 'application/x-www-form-urlencoded'
											}});
	# parse out the request id
	$response->{content} =~ /^    RID = (.*$)/m;
	my $rid=$1;

	# parse out the estimated time to completion
	$response->{content} =~ /^    RTOE = (.*$)/m;
	my $rtoe=$1;

	# wait for search to complete
	sleep $rtoe;

	# poll for results
	while (1)
	    {
	    sleep 5;

		$response = $ua->request('GET', "https://www.ncbi.nlm.nih.gov/blast/Blast.cgi?CMD=Get&TOOL=taxontree&EMAIL=$email&FORMAT_OBJECT=SearchInfo&RID=$rid");
		
	    if ($response->{content} =~ /\s+Status=WAITING/m)
	        {
			print STDERR "  Waiting for Blast result...\n";
	        next;
	        }

	   if ($response->{content} =~ /\s+Status=FAILED/m)
	        {
	        print STDERR "\nERROR: Search $rid failed; please report to blast-help\@ncbi.nlm.nih.gov.\n";
	        exit 4;
	        }

	    if ($response->{content} =~ /\s+Status=UNKNOWN/m)
	        {
	        print STDERR "\nERROR: Search $rid expired.\n";
	        exit 3;
	        }

	    if ($response->{content} =~ /\s+Status=READY/m) 
	        {
	        if ($response->{content} =~ /\s+ThereAreHits=yes/m)
	            {
				#  print STDERR "Search complete, retrieving results...\n";
	            last;
	            }
	        else
	            {
	            print STDERR "\nERROR: No hits found.\n";
	            exit 2;
	            }
	        }

		# if we get here, something unexpected happened.
		die "\nERROR: something unexpected happened to BLAST search.\n";
	    exit 5;
	    } # end poll loop

	# retrieve and display results
	$response = $ua->request('GET', "https://www.ncbi.nlm.nih.gov/blast/Blast.cgi?CMD=Get&TOOL=taxontree&EMAIL=$email&DESCRIPTIONS=$defMaxTarget&FORMAT_OBJECT=Alignment&ALIGNMENT_VIEW=Tabular&FORMAT_TYPE=Text&RID=$rid");
	my $blast_result = $response->{content};
	my $blastFileName = $pid."_blast.txt";
	open (BLAST, "> $blastFileName") or die;
	my @blast_result = split(/\n/, $blast_result);
	for(my $i = 0; $i < scalar @blast_result; $i++){
		next if ($blast_result[$i] =~ m/^#/);
		next if ($blast_result[$i] !~ m/^.+\t.+\t.+\t.+/);
		chomp $blast_result[$i];
		my @blastLine = split(/\t/, $blast_result[$i]);
		splice(@blastLine, 3, 1);
		print BLAST join("\t", @blastLine)."\n";
	}
	close BLAST;
	return($blastFileName);
	
}

sub localBlast {

	# do BLAST search in a local database.
	# input: the program name (blastp), database name, maximum number of targets to retrieve and the query input file name.
	# return: a string with blast result.
	my ($program, $database, $defMaxTarget, $queryBlastInput, $evalue) = @_;
	
	my $inputBlast = $queryBlastInput;
	my $outputBlast = $pid."_blast.txt";
	my $defOutputBlast = $programs{"blastSearch"}{$blastProgram}{"outName"};
	
	my $blastCommand = 	$programs{"blastSearch"}{$blastProgram}{"path"}." ".$programs{"blastSearch"}{$blastProgram}{"command"};
	$blastCommand =~ s/#INPUT/$inputBlast/g;
	$blastCommand =~ s/#OUTPUT/$outputBlast/g;
	$blastCommand =~ s/#DB/$database/g;
	$defOutputBlast =~ s/#OUTPUT/$outputBlast/g;
	$blastCommand =~ s/#EVALUE/$evalue/g;
	$blastCommand =~ s/#MAXTARGET/$defMaxTarget/g;
	$blastCommand =~ s/#NUMTHREADS/$numThreads/g;
	print "  Software: $blastProgram\n  BLAST max target sequences set to: $defMaxTarget\n  parameters: ".$programs{"blastSearch"}{$blastProgram}{"command"}."\n";
	system($blastCommand);
	#my $maxTarget2 = 10*$maxTarget;
	#my $blast_result = `$program -query $queryBlastInput -db $database -max_target_seqs $maxTarget2 -evalue $evalue -outfmt 6 -num_threads 8`;
	return ($defOutputBlast);
}

sub formatBlastResult {

	# Format BLAST result. Returns an array containing all BLAST hits gi numbers.
	print "Formatting Blast result...\n  Identity threshold: $tpident_cut\n  Max sequences to analyze:  $maxTarget\n";
	my $blast_result = $_[0];
	open(BLAST, "< ".$blast_result) or die;
	my @blast_result = <BLAST>;
	close (BLAST);
	
	my $formattedBlast = excludeOverlapHSP(@blast_result);
	if (scalar @$formattedBlast < 3){
		die "\nERROR: Less than 3 proteins retrieved from blast passed the identity threshold.\n       Try to set a lower threshold (selected threshold = $tpident_cut).\n";
	}
	print "  number of proteins that passed the identity threshold: ".scalar @$formattedBlast."\n";
	$formattedBlast = extractIdBlast($formattedBlast);
	
	return $formattedBlast;
	
}

sub excludeOverlapHSP {

	
	my @blast_result = @_;
	#my $searchQuery = quotemeta $queryInfo{"name"};
	my $queryLen = length $generalInfo{$queryID}{"seq"};
	
	my %hash_blast;
	my %treeHSPQuery;
	my %treeHSPSubject;
	my $webBlast;
	
	for (my $i = 0; $i < scalar @blast_result; $i++){

		$webBlast = 1 if (!$local);
		
		chomp $blast_result[$i];
		$blast_result[$i] =~ s/\r//g;
		
		my ($qseqid, $sseqid, $pident, $positive, $length, $mismatch, $gapopen, $qstart, 
							$qend, $sstart, $send, $evalue2, $bitscore, $rest);
	
		if ($webBlast){
			($qseqid, $sseqid, $pident, $mismatch, $gapopen, $qstart, 
							$qend, $sstart, $send, $evalue2, $bitscore, $positive, $rest) = split("\t", $blast_result[$i], 14);
		} else {
			($qseqid, $sseqid, $pident, $length, $mismatch, $gapopen, $qstart, 
							$qend, $sstart, $send, $evalue2, $bitscore, $rest) = split("\t", $blast_result[$i], 13);
		}
		
		# check data		
		next if (!$bitscore);
		$length = $qend - $qstart + 1;
		my $error;
		my $join = $length.$mismatch.$gapopen.$qstart.$qend.$sstart.$send;
		if ($join !~ /^\d+$/){
			die "\nERROR: Something wrong with this BLAST data.\n"
		}
		
		my $tpident = $pident*($qend - $qstart + 1)/$queryLen;

		# verify HSP overlapping - exclude those HSP that overlaps with others considering both query and subject;
		if (!(exists $hash_blast{$qseqid}{$sseqid})){
			$hash_blast{$qseqid}{$sseqid}{"tpident"} += $tpident;
			$hash_blast{$qseqid}{$sseqid}{"bitscore"} += $bitscore;
			$hash_blast{$qseqid}{$sseqid}{"length"} += $length;
			$treeHSPQuery{$qseqid}{$sseqid}{0}{"max"} = $qend;
			$treeHSPQuery{$qseqid}{$sseqid}{0}{"min"} = $qstart;
			$treeHSPQuery{$qseqid}{$sseqid}{0}{"maxWay"} = "NULL";
			$treeHSPQuery{$qseqid}{$sseqid}{0}{"minWay"} = "NULL";
			
			$treeHSPSubject{$qseqid}{$sseqid}{0}{"max"} = $send;
			$treeHSPSubject{$qseqid}{$sseqid}{0}{"min"} = $sstart;
			$treeHSPSubject{$qseqid}{$sseqid}{0}{"maxWay"} = "NULL";
			$treeHSPSubject{$qseqid}{$sseqid}{0}{"minWay"} = "NULL";
		} else {
		
			#verify if subject overlaps;
			my $waySub = 0;
			my $ratio = 64;
			my $directionSub = '';
			my $control = 0;
			while ($waySub ne "NULL"){
				if ($send < $treeHSPSubject{$qseqid}{$sseqid}{$waySub}{"min"}){
					if ($treeHSPSubject{$qseqid}{$sseqid}{$waySub}{"minWay"} eq "NULL"){
						$directionSub = "minWay";
						last;
					} else {
						$waySub = $treeHSPSubject{$qseqid}{$sseqid}{$waySub}{"minWay"};
						$ratio /= 2;
						next;
					}
				} elsif ($sstart > $treeHSPSubject{$qseqid}{$sseqid}{$waySub}{"max"}){
					if ($treeHSPSubject{$qseqid}{$sseqid}{$waySub}{"maxWay"} eq "NULL"){
						$directionSub = "maxWay";
						last;
					} else {
						$waySub = $treeHSPSubject{$qseqid}{$sseqid}{$waySub}{"maxWay"};
						$ratio /= 2;
						next;
					}
				} else { # HSP overlaps
					$control = 1;
					last;
				}
			}
			if ($control == 1){ 
				next;
			} 
			my $waySubNew = $waySub;
			if ($directionSub eq "minWay"){
				$waySubNew -= $ratio;
			} else {
				$waySubNew += $ratio;
			}
			
			$ratio = 64;
			my $wayQry = 0;
			my $directionQry = '';
			#verify if query overlaps;
			while ($wayQry ne "NULL"){
				if ($qend < $treeHSPQuery{$qseqid}{$sseqid}{$wayQry}{"min"}){
					if ($treeHSPQuery{$qseqid}{$sseqid}{$wayQry}{"minWay"} eq "NULL"){
					$directionQry = "minWay";
						last;
					} else {
						$wayQry = $treeHSPQuery{$qseqid}{$sseqid}{$wayQry}{"minWay"};
						$ratio /= 2;
						next;
					}
				} elsif ($qstart > $treeHSPQuery{$qseqid}{$sseqid}{$wayQry}{"max"}){
					if ($treeHSPQuery{$qseqid}{$sseqid}{$wayQry}{"maxWay"} eq "NULL"){
						$directionQry = "maxWay";
						last;
					} else {
						$wayQry = $treeHSPQuery{$qseqid}{$sseqid}{$wayQry}{"maxWay"};
						$ratio /= 2;
						next;
					}
				} else { # HSP overlaps
					$control = 1;
					last;
				}
			}
			if ($control == 1){ 
				next;
			}
			my $wayQryNew = $wayQry;
			if ($directionQry eq "minWay"){
				$wayQryNew -= $ratio;
			} else {
				$wayQryNew += $ratio;
			}
			
			$treeHSPSubject{$qseqid}{$sseqid}{$waySub}{$directionSub} = $waySubNew;
			$treeHSPSubject{$qseqid}{$sseqid}{$waySubNew}{"max"} = $send;
			$treeHSPSubject{$qseqid}{$sseqid}{$waySubNew}{"min"} = $sstart;
			$treeHSPSubject{$qseqid}{$sseqid}{$waySubNew}{"maxWay"} = "NULL";
			$treeHSPSubject{$qseqid}{$sseqid}{$waySubNew}{"minWay"} = "NULL";
			
			$treeHSPQuery{$qseqid}{$sseqid}{$wayQry}{$directionQry} = $wayQryNew;
			$treeHSPQuery{$qseqid}{$sseqid}{$wayQryNew}{"max"} = $qend;
			$treeHSPQuery{$qseqid}{$sseqid}{$wayQryNew}{"min"} = $qstart;
			$treeHSPQuery{$qseqid}{$sseqid}{$wayQryNew}{"maxWay"} = "NULL";
			$treeHSPQuery{$qseqid}{$sseqid}{$wayQryNew}{"minWay"} = "NULL";
			
			$hash_blast{$qseqid}{$sseqid}{"tpident"} += $tpident; # increment tpident
			$hash_blast{$qseqid}{$sseqid}{"length"} += $length; # increment length
			$hash_blast{$qseqid}{$sseqid}{"bitscore"} += $bitscore; # increment bitscore

		}
		
	}
	my @keys = keys %hash_blast;
	print "  number of proteins retrieved from BLAST: ".scalar (keys %{$hash_blast{$keys[0]}})."\n";
	my @giList_tpident;
	foreach my $geneID(keys %hash_blast){

		foreach my $subject(sort {$hash_blast{$geneID}{$b}{"tpident"} <=> $hash_blast{$geneID}{$a}{"tpident"}} keys %{$hash_blast{$geneID}}){
			next if ($hash_blast{$geneID}{$subject}{"tpident"} < $tpident_cut);
			if ($subject =~ m/;/){
				my @subject = split(/;/, $subject);
				foreach my $subSubject(@subject){
					push (@giList_tpident, $subSubject);
				}
			} else {
				push (@giList_tpident, $subject);
			}
			
			
		}

	}
	
	return \@giList_tpident;
}

sub extractIdBlast {
	my $refblastId = $_[0];
	my $pattern = $delimiter;
	my $pos = $position;
	if (!$local){
		$pattern = $webBlastDelimiter;
		$pos = $webBlastPosition;
	}
	my @blastID = @$refblastId;
	my @giList;
	foreach my $subject(@blastID){
		if ($subject =~ m/;/){
				my @subject = split(/;/, $subject);
				foreach my $subSubject(@subject){
					if ($subSubject =~ m/$pattern/){
						my @subSubject = split(/$pattern/, $subSubject); # delimiter pos
						push (@giList, $subSubject[$pos]);
					} else {
						push (@giList, $subSubject);
					}
				}
		} else {
			if ($subject =~ m/$pattern/){
				my @subject = split(/$pattern/, $subject); # delimiter pos
				push (@giList, $subject[$pos]);
			} else {
				push (@giList, $subject);
			}
		}
	}
	return \@giList;
}

sub verifyID{
	
	my $id = $_[0];
	
	if ($id =~ m/^[A-Z0-9]{3,5}_[A-Z0-9]{3,5}([-\.]\d+)?$|^[OPQ][0-9][A-Z0-9]{3}[0-9]_[A-Z0-9]{3,5}([-\.]\d+)?$|^[A-NR-Z][0-9]([A-Z][A-Z0-9]{2}[0-9]){1,2}_[A-Z0-9]{3,5}([-\.]\d+)?$/){
		return "uniprot_id";
	} elsif ($id =~ m/^[OPQ][0-9][A-Z0-9]{3}[0-9]([-\.]\d+)?$|^[A-NR-Z][0-9]([A-Z][A-Z0-9]{2}[0-9]){1,2}([-\.]\d+)?$/){
		return "uniprot_ac";
	} elsif ($id =~ m/^[0-9]+$/){
		return "ncbi_gi";
	} elsif ($id =~ m/^(NC|AC|NG|NT|NW|NZ|NM|NR|XM|XR|NP|AP|XP|YP|WP|ZP)_\d+(\.\d+)?$/ || 
				$id =~ m/^[^\d\W]{3}\d{5}(\.\d+)?$/ || 
				$id =~ m/^[^\d\W]{2}\d{6}(\.\d+)?$/ || 
				$id =~ m/^[^\d\W]{1}\d{5}(\.\d+)?$/ || 
				$id =~ m/^[^\d\W]{2}\d{8}(\.\d+)?$/ || 
				$id =~ m/^[^\d\W]{3}\d{7}(\.\d+)?$/){
		return "ncbi_ac";
	} else {
		return 0;
	}
}

sub defineIdSubject {

	my @subjectList = @_;
	my $note = 0;
	my %definedID;
	#my (@uniprotAC, @uniprotACIso, @uniprotID, @refseqGI, @refseqAC);
	my %hashJoinIDUniprot;
	my %hashJoinIDNCBI;
	#my $i = 0;
	my %undefinedIDType;
	my %version2accession;
	my %accession2version;
	my %listAccessions;
	my %geneID2geneName;
	my %accession2gi;
	my %gi2accession;
	my @gene2retrieve;
	foreach my $id(@subjectList){
		chomp $id;
		my $idNoVersion = $id;
		#$id =~ s/\.\d+//;
		next if ($id =~ m/^$/);
		$definedID{$id}{"name"} = $id;
		
		my $subjectType = verifyID($id);
		
		if(exists $treeTableHash{$id}){
			$definedID{$id}{"type"} = "other";
			$definedID{$id}{"id"} = $id;
			$definedID{$id}{"accession"} = $id;
			$definedID{$id}{"geneID"} = "NULL";
			$definedID{$id}{"geneName"} = "NULL";
			$definedID{$id}{"txid"} = $treeTableHash{$id};
		} else {
			if (!$subjectType){
			
			print "  NOTE: Could not recognize $id as NCBI or Uniprot accession...\n        Accession was discarded.\n";
			
			} elsif ($subjectType eq "uniprot_id"){
				$definedID{$id}{"type"} = "uniprot_id";
				$hashJoinIDUniprot{$id} = "uniprot_id";
			} elsif ($subjectType eq "uniprot_ac"){
				$definedID{$id}{"id"} = $id;
				$definedID{$id}{"type"} = "uniprot_ac";
				$idNoVersion =~ s/[-\.]\d+$//;
				$listAccessions{"uniprot_ac"}{$idNoVersion} = 1;
				$hashJoinIDUniprot{$id} = "uniprot_ac";			
			} elsif ($subjectType eq "ncbi_gi"){
				
				$definedID{$id}{"type"} = "ncbi_gi";
				$hashJoinIDNCBI{$id} = "ncbi_gi";
			} elsif ($subjectType eq "ncbi_ac"){
				
				$definedID{$id}{"id"} = $id;
				$definedID{$id}{"type"} = "ncbi_ac";

				$hashJoinIDNCBI{$id} = "ncbi_ac";
				$idNoVersion =~ s/\.\d+$//;
			}
		}		
		
		$version2accession{$idNoVersion}{$id} = 1;
		$accession2version{$id} = $idNoVersion;
		$listAccessions{$subjectType}{$idNoVersion} = 1;
	}
	
	my $retrieveWeb = 1;
	
	# search in local database?
	if ($mysqlInfo{"connection"}){
		my $n = -1;
		my $m = -100;
		
		my @uniprotAC = keys %{$listAccessions{"uniprot_ac"}};
		my @uniprotID = keys %{$listAccessions{"uniprot_id"}};
		if (scalar @uniprotAC + scalar @uniprotID > 0 && exists $mysqlInfo{"tables"}{"uniprot_idmapping"}){
			my $uniprotMapTable = $mysqlInfo{"tables"}{"uniprot_idmapping"};
			print "  Mapping Uniprot accessions from the local database...\n";
			my %undefinedID;
			# open uniprotDB
			if (scalar @uniprotAC > 0) {
				do {
					$n = $n + 100;
					$m = $m + 100;
					$n = $#uniprotAC if ($n > $#uniprotAC);
					my $results = $wire->query("SELECT * FROM ".$uniprotMapTable." where accession in ('".join("','", @uniprotAC[$m .. $n])."');");
					while (my $row = $results->next_hash) {
						my $id2 = $row->{accession};
						my $ac = $row->{entry};
						my $geneID = $row->{geneid};
						my $txid = $row->{txid};
						delete $listAccessions{"uniprot_ac"}{$id2};
						foreach my $id (keys %{$version2accession{$id2}}){
							if (exists $hashJoinIDUniprot{$id}){
								$definedID{$id}{"id"} = $id;
								$definedID{$id}{"accession"} = $ac;
								if ($geneID){
									$definedID{$id}{"geneID"} = $geneID;
									$geneID2geneName{$geneID} = 1;
								} else {
									$definedID{$id}{"geneID"} = "NULL";
									$definedID{$id}{"geneName"} = "NULL";
								}
								$definedID{$id}{"txid"} = $txid;
								delete $hashJoinIDUniprot{$id};
							} 
						}
					}
				} while ($n < $#uniprotAC);
				$n = -1;
				$m = -100;
			}
			
			if (scalar @uniprotID > 0) {
				do {
					$n = $n + 100;
					$m = $m + 100;
					$n = $#uniprotID if ($n > $#uniprotID);
					my $results = $wire->query("SELECT * FROM ".$uniprotMapTable." where entry in ('".join("','", @uniprotID[$m .. $n])."');");
					while (my $row = $results->next_hash) {
						my $id = $row->{accession};
						my $ac = $row->{entry};
						my $geneID = $row->{geneid};
						my $txid = $row->{txid};
						
						delete $listAccessions{"uniprot_id"}{$id};
						if (exists $hashJoinIDUniprot{$ac}){
							$definedID{$ac}{"id"} = $id;
							$definedID{$ac}{"accession"} = $ac;
							if ($geneID){
								$definedID{$ac}{"geneID"} = $geneID;
								$geneID2geneName{$geneID} = 1;
							} else {
								$definedID{$ac}{"geneID"} = "NULL";
								$definedID{$ac}{"geneName"} = "NULL";
							}
							$definedID{$ac}{"txid"} = $txid;
							delete $hashJoinIDUniprot{$ac};
						}
					}
				} while ($n < $#uniprotID);
				$n = -1;
				$m = -100;
			}
		}
		
		my @refseqGI = keys %{$listAccessions{"ncbi_gi"}};
		my @refseqAC = keys %{$listAccessions{"ncbi_ac"}};
		if (scalar @refseqGI + scalar @refseqAC > 0 && exists $mysqlInfo{"tables"}{"refseq_idmapping"}){
			my $refseqMapTable = $mysqlInfo{"tables"}{"refseq_idmapping"};
			my %undefinedID;
			# open ncbiDB
			print "  Mapping RefSeq accessions from the local database...\n";
			
			if (scalar @refseqGI > 0) {
				do {
					$n = $n + 100;
					$m = $m + 100;
					$n = $#refseqGI if ($n > $#refseqGI);
					my $results = $wire->query("SELECT * FROM ".$refseqMapTable." where gi in ('".join("','", @refseqGI[$m .. $n])."');");
					while (my $row = $results->next_hash) {
						my $id = $row->{gi};
						my $ac = $row->{accession};
						my $txid = $row->{txid};
						my $geneID = $row->{geneid};
						delete $listAccessions{"ncbi_gi"}{$id};
						
						if (exists $hashJoinIDNCBI{$id}){
							$definedID{$id}{"accession"} = $id;
							$definedID{$id}{"id"} = $ac;
							if ($geneID){
								$definedID{$id}{"geneID"} = $geneID;
								$geneID2geneName{$geneID} = 1;
							} else {
								$definedID{$id}{"geneID"} = "NULL";
								$definedID{$id}{"geneName"} = "NULL";
								#push (@gene2retrieve, $id);
							}
							$definedID{$id}{"txid"} = $txid;
							delete $hashJoinIDNCBI{$id};
							
						} 
					}
				} while($n < $#refseqGI);
				$n = -1;
				$m = -100;
			} 
			
			if (scalar @refseqAC > 0) {
			
				do {
					$n = $n + 100;
					$m = $m + 100;
					$n = $#refseqAC if ($n > $#refseqAC);
					
					my $results = $wire->query("SELECT * FROM ".$refseqMapTable." where accession in ('".join("','", @refseqAC[$m .. $n])."');");
					while (my $row = $results->next_hash) {
						my $id = $row->{gi};
						my $ac2 = $row->{accession};
						my $geneID = $row->{geneid};
						my $txid = $row->{txid};
						delete $listAccessions{"ncbi_ac"}{$ac2};
						
						#my @originalId = keys %{$mapRefSeqVer{$ac2}};
						foreach my $ac (keys %{$version2accession{$ac2}}){
							if (exists $hashJoinIDNCBI{$ac}){
								$definedID{$ac}{"id"} = $ac;
								$definedID{$ac}{"accession"} = $id;
								if ($geneID){
									$definedID{$ac}{"geneID"} = $geneID;
									$geneID2geneName{$geneID} = 1;
								} else {
									$definedID{$ac}{"geneID"} = "NULL";
									$definedID{$ac}{"geneName"} = "NULL";
									#push (@gene2retrieve, $id);
									$accession2gi{$id} = $ac;
									
								}
								$definedID{$ac}{"txid"} = $txid;
								delete $hashJoinIDNCBI{$ac};
							}
						}
					}
				} while ($n < $#refseqAC);
				$n = -1;
				$m = -100;
			}
		}
		
		my $missingAccessionCount = scalar (keys %hashJoinIDNCBI) + scalar (keys %hashJoinIDUniprot);
		if ($missingAccessionCount > 0){
			my @accessions = (keys %hashJoinIDNCBI, keys %hashJoinIDUniprot);
			if ($internetConnection == 1){
				print "  NOTE: there are $missingAccessionCount accession(s) not found in local database.\n        TaxOnTree will try to retrieve its(their) info from web.\n";
			} else {
				print "  NOTE: there is(are) $missingAccessionCount accession(s) not found in local database.\n        TaxOnTree discarded it(then) as there is no internet connection.\n";
				for (my $i = 0; $i < scalar @accessions; $i++){
					if (exists $definedID{$accessions[$i]}){
						delete $definedID{$accessions[$i]};
					}
					print "        $accessions[$i] was discarded.\n";
				}
			}
		} else {
			if (scalar @gene2retrieve == 0){
				$retrieveWeb = 0;
			}
		}
	}
	
	if ($internetConnection == 1){
		if ($retrieveWeb == 1){
			print "  Retrieving info from the web...  ";
			my $note = 0;
			#my %geneID2geneName;
			if (scalar (keys %hashJoinIDUniprot) > 0){
				my @uniprotAC = keys %{$listAccessions{"uniprot_ac"}};
				my @uniprotID = keys %{$listAccessions{"uniprot_id"}};
				my $n = -1;
				my $m = -50;
				if (scalar @uniprotAC > 0){
					#my @listUniprot2 = (@uniprotAC, @uniprotACIso);
					do {
						$n = $n + 50;
						$m = $m + 50;
									
						$n = $#uniprotAC if ($n > $#uniprotAC);
						my $url_fetch_seq = 'http://www.uniprot.org/uniprot/?query=accession:'.join("+OR+accession:",@uniprotAC[$m .. $n]).'&force=yes&format=tab&columns=id,entry%20name,genes(PREFERRED),database(GeneID),organism-id';
						my $response = HTTP::Tiny->new->get($url_fetch_seq);
						my $link_txid = $response->{content};
						my @link_txid = split("\n", $link_txid);
						for (my $i = 1; $i < scalar @link_txid; $i++){
							next if ($link_txid[$i] =~ m/^$/);
							my @table = split("\t", $link_txid[$i]);
							my $gi2 = $table[0];
							my $accession = $table[1];
							my $geneID = $table[3];
							if (!$geneID){
								$geneID = "NULL";
							} else {
								if ($geneID =~ /;/){
									my @geneID = split(";", $geneID);
									@geneID = sort { $b<=>$a } @geneID;
									$geneID = $geneID[0];
								}
								$geneID2geneName{$geneID} = "NULL";
							}
							my $txid = $table[4];
							delete $listAccessions{"uniprot_ac"}{$gi2};
							
							foreach my $gi (keys %{$version2accession{$gi2}}){
								if (exists $hashJoinIDUniprot{$gi}){
									if (!$txid){
										print "\n  NOTE: Accession $gi was discarded. Could not retrieve its txid.";
										$note = 1;
										delete $definedID{$gi};
									} else {
										$definedID{$gi}{"accession"} = $accession;
										$definedID{$gi}{"geneID"} = $geneID;
										#$definedID{$gi}{"geneName"} = $geneName;
										$definedID{$gi}{"txid"} = $txid;
									}
									delete $hashJoinIDUniprot{$gi};
								}
							}
						}
							
						sleep 1;		
					
					} while ($n < $#uniprotAC);
					$n = -1;
					$m = -50;
				}
				
				if (scalar @uniprotID > 0){
					do {
						$n = $n + 50;
						$m = $m + 50;
						$n = $#uniprotID if ($n > $#uniprotID);
						
						my $url_fetch_seq = 'http://www.uniprot.org/uniprot/?query=mnemonic:'.join("+OR+mnemonic:",@uniprotID[$m .. $n]).'&force=yes&format=tab&columns=id,entry%20name,genes(PREFERRED),database(GeneID),organism-id';
						my $response = HTTP::Tiny->new->get($url_fetch_seq);
						my $link_txid = $response->{content};
						my @link_txid = split("\n", $link_txid);
						for (my $i = 1; $i < scalar @link_txid; $i++){
							next if ($link_txid[$i] =~ m/^$/);
							my @table = split("\t", $link_txid[$i]);
							my $gi = $table[0];
							my $accession = $table[1];
							my $geneID = $table[3];
							if (!$geneID){
								$geneID = "NULL";
							} else {
								if ($geneID =~ /;/){
									my @geneID = split(";", $geneID);
									@geneID = sort { $b<=>$a } @geneID;
									$geneID = $geneID[0];
								}
								$geneID2geneName{$geneID} = "NULL";
							}
							#$geneID =~ s/;//g;
							#my $geneName = $table[2];
							my $txid = $table[4];
							delete $listAccessions{"uniprot_id"}{$accession};
							
							if (exists $hashJoinIDUniprot{$accession}){
								$definedID{$accession}{"id"} = $gi;
								$definedID{$accession}{"accession"} = $accession;
								$definedID{$accession}{"geneID"} = $geneID;
								$definedID{$accession}{"txid"} = $txid;
								delete $hashJoinIDUniprot{$accession};
							}
						}
							
						sleep 1;		
					
					} while ($n < $#uniprotID);
					$n = -1;
					$m = -50;
				}
				
				if (scalar keys %hashJoinIDUniprot > 0){
					foreach my $missingID(keys %hashJoinIDUniprot){
						print "\n  NOTE: Could not retrieve data of $missingID. This entry was discarded.";
						$note = 1;
						delete $definedID{$missingID} if (exists $definedID{$missingID});
					}
					
				}
			}
			
			my $n = -1;
			my $m = -50;
			my @refseqGI = keys %{$listAccessions{"ncbi_gi"}};
			my @refseqAC = keys %{$listAccessions{"ncbi_ac"}};
			my (@refseqProt, @refseqNucl);
			
			if (scalar @refseqGI + scalar @refseqAC > 0){
				my %refseqData;
				my @allRefseqAccession = (@refseqGI, @refseqAC);
				do {
					$n = $n + 50;
					$m = $m + 50;
					$n = $#allRefseqAccession if ($n > $#allRefseqAccession);
					
					my @ac2retrieve = @allRefseqAccession[$m .. $n];
					my $url_fetch_id = "https://www.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?tool=taxontree&email=$email&db=protein&retmode=text&rettype=seqid&id=".join(",",@ac2retrieve);
					my $fetch_lineage2 = retrieveEFetch($url_fetch_id);
					
					my @ids = split(/\n\n/, $fetch_lineage2);
					my %accessionRetrieved;
					foreach my $ids (@ids){
						$ids =~ /accession \"([^\" ]+)\" ,/;
						my $acc = $1;
						$ids =~  /version (\d+) /;
						my $ver = $1;
						$ids =~  /Seq-id ::= gi (\d+)/;
						my $gi = $1;
						$accessionRetrieved{$gi} = 1;
						$accessionRetrieved{$acc} = 1;
						if ($gi && $acc){
							$accession2gi{$gi} = $acc.".".$ver;
							$gi2accession{$acc.".".$ver} = $gi;
						}
						
					}
					
					foreach my $ac(@ac2retrieve){
						my $ac2 = $ac;
						$ac2 =~ s/\.\d+$//;
						if(!exists $accessionRetrieved{$ac2}){
							push (@refseqNucl, $ac);
						} else {
							push (@refseqProt, $ac);
						}
					}
				} while ($n < $#allRefseqAccession);
				$n = -1;
				$m = -50;
				
				if (scalar @refseqNucl > 0){
					
					do {
						$n = $n + 50;
						$m = $m + 50;
						$n = $#refseqNucl if ($n > $#refseqNucl);
						
						my @ac2retrieve = @refseqNucl[$m .. $n];
						my $url_fetch_id = "https://www.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?tool=taxontree&email=$email&db=protein&retmode=text&rettype=seqid&id=".join(",",@ac2retrieve);
						my $fetch_lineage2 = retrieveEFetch($url_fetch_id);
						
						my @ids = split(/\n\n/, $fetch_lineage2);
						my %accessionRetrieved;
						foreach my $ids (@ids){
							$ids =~ /accession \"([^\" ]+)\" ,/;
							my $acc = $1;
							$ids =~  /version (\d+) /;
							my $ver = $1;
							$ids =~  /Seq-id ::= gi (\d+)/;
							my $gi = $1;
							$accessionRetrieved{$gi} = 1;
							$accessionRetrieved{$acc} = 1;
							if ($gi && $acc){
								$accession2gi{$gi} = $acc.".".$ver;
								$gi2accession{$acc.".".$ver} = $gi;
							}
							
						}
						
					} while ($n < $#refseqNucl);
				}
				$n = -1;
				$m = -50;
				
				if (scalar @refseqProt > 0){
					do {
						$n = $n + 50;
						$m = $m + 50;
						$n = $#refseqProt if ($n > $#refseqProt);
						my $url_fetch_seq = "https://www.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?tool=taxontree&email=$email&db=protein&retmode=xml&rettype=fasta&seq_stop=1&id=".join(",",@refseqProt[$m .. $n]);
						my $fetch_lineage = retrieveEFetch($url_fetch_seq);
						
						my $xs2 = XML::Simple->new();
						my $doc_lineage = $xs2->XMLin($fetch_lineage, ForceArray => ["TSeq"]);
						my @linkSet = @{$doc_lineage->{"TSeq"}};
						
						foreach my $link(@linkSet){
						
							my $type = $link->{"TSeq_seqtype"}->{"value"};
							#my $gi = $link->{"TSeq_gi"};
							my $accession = $link->{"TSeq_accver"};
							$accession =~ /\.(\d+)$/;
							my $version = $1;
							$accession =~ s/\.\d+//;
							my $txid = $link->{"TSeq_taxid"};
							#my $seq = $link->{"TSeq_sequence"};

							$refseqData{$accession}{"v"}{$version}{"txid"} = $txid;
							$refseqData{$accession}{"v"}{$version}{"chemicalType"} = $type;
							#$refseqData{$accession}{"v"}{$version}{"seq"} = $seq;
							if (exists $gi2accession{$accession.".".$version}){
								my $gi = $gi2accession{$accession.".".$version};
								$refseqData{$accession}{"v"}{$version}{"accession"} = $gi;
								$refseqData{$accession}{"v"}{$version}{"fastaHeader"} = "gi\|".$gi."\|ref\|".$accession."\|";
							} else {
								$refseqData{$accession}{"v"}{$version}{"fastaHeader"} = "ref\|".$accession."\|";
							}
							$refseqData{$accession}{"v"}{$version}{"id"} = $accession.".".$version;
							
							if (exists $refseqData{$accession}{"vmax"}){
								$refseqData{$accession}{"vmax"} = $version if ($version > $refseqData{$accession}{"vmax"});
							} else {
								$refseqData{$accession}{"vmax"} = $version;
							}
							#$accession2gi{$gi} = $refseqData{$accession}{"v"}{$version}{"id"};
						}
						
						sleep 1;
						
					} while ($n < $#refseqProt);
					$n = -1;
					$m = -50;
				}
				
				if (scalar @refseqNucl > 0){
					do {
						$n = $n + 50;
						$m = $m + 50;
						$n = $#refseqNucl if ($n > $#refseqNucl);
						my $url_fetch_seq = "https://www.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?tool=taxontree&email=$email&db=nuccore&retmode=xml&rettype=fasta&seq_stop=1&id=".join(",",@refseqNucl[$m .. $n]);
						my $fetch_lineage = retrieveEFetch($url_fetch_seq);
						
						my $xs2 = XML::Simple->new();
						my $doc_lineage = $xs2->XMLin($fetch_lineage, ForceArray => ["TSeq"]);
						my @linkSet = @{$doc_lineage->{"TSeq"}};
						
						foreach my $link(@linkSet){
						
							my $type = $link->{"TSeq_seqtype"}->{"value"};
							#my $gi = $link->{"TSeq_gi"};
							my $accession = $link->{"TSeq_accver"};
							$accession =~ /\.(\d+)$/;
							my $version = $1;
							$accession =~ s/\.\d+//;
							my $txid = $link->{"TSeq_taxid"};
							#my $seq = $link->{"TSeq_sequence"};

							$refseqData{$accession}{"v"}{$version}{"txid"} = $txid;
							$refseqData{$accession}{"v"}{$version}{"chemicalType"} = $type;
							#$refseqData{$accession}{"v"}{$version}{"seq"} = $seq;
							if (exists $gi2accession{$accession.".".$version}){
								my $gi = $gi2accession{$accession.".".$version};
								$refseqData{$accession}{"v"}{$version}{"accession"} = $gi;
								$refseqData{$accession}{"v"}{$version}{"fastaHeader"} = "gi\|".$gi."\|ref\|".$accession."\|";
							} else {
								$refseqData{$accession}{"v"}{$version}{"fastaHeader"} = "ref\|".$accession."\|";
							}
							$refseqData{$accession}{"v"}{$version}{"id"} = $accession.".".$version;
							
							if (exists $refseqData{$accession}{"vmax"}){
								$refseqData{$accession}{"vmax"} = $version if ($version > $refseqData{$accession}{"vmax"});
							} else {
								$refseqData{$accession}{"vmax"} = $version;
							}
							#$accession2gi{$gi} = $refseqData{$accession}{"v"}{$version}{"id"};
						}
						
						sleep 1;
						
					} while ($n < $#refseqNucl);
					$n = -1;
					$m = -50;
				}
				
				foreach my $refseqAC (@refseqAC){
					
					if (exists $refseqData{$refseqAC}){
						foreach my $identifier2(keys %{$version2accession{$refseqAC}}){
							my ($identifier, $version);
							$identifier = $identifier2;
							$version = $refseqData{$refseqAC}{"vmax"};
							if ($identifier2 =~ /\.\d+/){
								($identifier, $version) = split(/\./, $identifier2, 2);
							}
							
							if (exists $refseqData{$identifier}{"v"}{$version}){
								if (exists $refseqData{$identifier}{"v"}{$version}{"accession"}){
									$definedID{$identifier2}{"accession"} = $refseqData{$identifier}{"v"}{$version}{"accession"};
									push (@gene2retrieve, $definedID{$identifier2}{"accession"}) if ($refseqData{$identifier}{"v"}{$version}{"chemicalType"} eq "protein"); # to retrieve geneID, GI is required
								}
								#$definedID{$identifier2}{"id"} = $identifier2;
								$definedID{$identifier2}{"txid"} = $refseqData{$identifier}{"v"}{$version}{"txid"};
								$definedID{$identifier2}{"chemicalType"} = $refseqData{$identifier}{"v"}{$version}{"chemicalType"};
								#$definedID{$identifier2}{"seq"} = $refseqData{$identifier}{"v"}{$version}{"seq"};
								$definedID{$identifier2}{"geneID"} = "NULL";
								$definedID{$identifier2}{"geneName"} = "NULL";
								
							} elsif (exists $refseqData{$identifier}) {
								$version = $refseqData{$identifier}{"vmax"};
								if (exists $refseqData{$identifier}{"v"}{$version}{"accession"}){
									$definedID{$identifier2}{"accession"} = $refseqData{$identifier}{"v"}{$version}{"accession"};
									push (@gene2retrieve, $definedID{$identifier2}{"accession"}) if ($refseqData{$identifier}{"v"}{$version}{"chemicalType"} eq "protein"); # to retrieve geneID, GI is required
								}
								#$definedID{$identifier2}{"id"} = $identifier2;
								$definedID{$identifier2}{"txid"} = $refseqData{$identifier}{"v"}{$version}{"txid"};
								$definedID{$identifier2}{"chemicalType"} = $refseqData{$identifier}{"v"}{$version}{"chemicalType"};
								$definedID{$identifier2}{"geneID"} = "NULL";
								$definedID{$identifier2}{"geneName"} = "NULL";
								
							} else {
								print "\n  NOTE: Could not retrieve data of $refseqAC. This entry was discarded.";
								$note = 1;
								delete $definedID{$refseqAC} if (exists $definedID{$refseqAC});
							}
						}
					} else {
						print "\n  NOTE: Could not retrieve data of $refseqAC. This entry was discarded.";
						$note = 1;
						delete $definedID{$refseqAC} if (exists $definedID{$refseqAC});
					}
					
				}
				foreach my $refseqGI (@refseqGI){
					if (exists ($accession2gi{$refseqGI})){
						my $accession2 = $accession2gi{$refseqGI};
						my ($identifier, $version) = split(/\./, $accession2, 2);
						if (exists $refseqData{$identifier}{"v"}{$version}){
							$definedID{$refseqGI}{"id"} = $accession2gi{$refseqGI};
							$definedID{$refseqGI}{"name"} = $refseqGI;
							$definedID{$refseqGI}{"accession"} = $refseqGI;
							$definedID{$refseqGI}{"txid"} = $refseqData{$identifier}{"v"}{$version}{"txid"};
							$definedID{$refseqGI}{"chemicalType"} = $refseqData{$identifier}{"v"}{$version}{"chemicalType"};
							#$definedID{$refseqGI}{"seq"} = $refseqData{$identifier}{"v"}{$version}{"seq"};
							push (@gene2retrieve, $refseqGI) if ($refseqData{$identifier}{"v"}{$version}{"chemicalType"} eq "protein"); # to retrieve geneID, GI is required
						} else {
							print "\n  NOTE: Could not retrieve data of $refseqGI. This entry was discarded.";
							$note = 1;
							delete $definedID{$refseqGI};
						}
					} else {
						print "\n  NOTE: Could not retrieve data of $refseqGI. This entry was discarded.";
						delete $definedID{$refseqGI};
					}
				}
			}
			
			# retrieve geneID of missing accession
			if (scalar @gene2retrieve > 0){
				#if (exists $leafNameOptions{"genename"} or $leafNameOptions{"geneid"}){
					my $ref_linkGene = retrieveGeneNCBI(\@gene2retrieve);
					my %linkGene = %$ref_linkGene;
					foreach my $keySubject(@gene2retrieve){
						
						my $geneID = "NULL";
						
						if (exists $linkGene{$keySubject}){
							$geneID = $linkGene{$keySubject}{"geneID"};
							$geneID2geneName{$geneID} = "NULL";
						} 
						
						if (exists $definedID{$keySubject}){
							$definedID{$keySubject}{"geneID"} = $geneID;
						}
						
						if (exists $accession2gi{$keySubject}){
							$keySubject = $accession2gi{$keySubject};
							if (exists $definedID{$keySubject}){
								$definedID{$keySubject}{"geneID"} = $geneID;
							}
							$keySubject =~ s/\.\d+$//;
							if (exists $definedID{$keySubject}){
								$definedID{$keySubject}{"geneID"} = $geneID;
							}
						}						
					}
				#}
			}
		}
	}
	
	# Retrieve gene name
	my $gene2nameRef = retrieveGeneName(keys %geneID2geneName);
	foreach my $id (keys %definedID){
		if ($definedID{$id}{"geneID"}){
			next if ($definedID{$id}{"geneID"} eq "NULL");
			if (exists $gene2nameRef->{$definedID{$id}{"geneID"}}){
				$definedID{$id}{"geneName"} = $gene2nameRef->{$definedID{$id}{"geneID"}};
			} else {
				$definedID{$id}{"geneName"} = "NULL";
			}
		}
	}
	
	if($note == 0){
		print "OK!\n";
	} else {
		print "\n";
	}
	
	return \%definedID;
}

sub retrieveEFetch {
	my $url_fetch_id = $_[0];
	my $fetch_lineage2;
	my $errorCount2 = -1;
	my $maxErrorCount = 100;
	my $maxSleep = 30;
	my $response;
	do {
		$response = HTTP::Tiny->new->get($url_fetch_id);
		$errorCount2++;
		my $sleepTime = 2 ** $errorCount2;
		$sleepTime = $maxSleep if ($sleepTime > $maxSleep);
		sleep $sleepTime;
	#} while ($fetch_lineage2 =~ m/<p>The server encountered an internal error or|<\/ERROR>|<\/Error>|<title>Bad Gateway!<\/title>|<title>Service unavailable!<\/title>|Error occurred:/ and $errorCount2 < 5);
	} while (!$response->{success} and $errorCount2 < $maxErrorCount);
	if (!$response->{success}){
		die "\nERROR: Sorry, access to the following URL retrieved error $maxErrorCount times:\n       $url_fetch_id\n       ".$response->{reason}."\n       Please, try to run TaxOnTree again later.";
	}
	
	return $response->{content};
}

sub retrieveGeneNCBI {

	my $subject_list = $_[0];
	my @gilist = @$subject_list;
	my %geneIDlist;
	my %linkGene;
	my %protExists;

	my $n = -1;
	my $m = -50;
	my @giObsolete;
	
	if (scalar @gilist > 0){
		do {
			$n = $n + 50;
			$m = $m + 50;
			$n = $#gilist if ($n > $#gilist);
			
			my $url_fetch_seq = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/elink.fcgi?tool=taxontree&email=$email&dbfrom=protein&db=gene&id=".join("&id=",@gilist[$m .. $n]);
			my $fetch_lineage = retrieveEFetch($url_fetch_seq);
			
			my $xs1 = XML::Simple->new();
			my $doc_link = $xs1->XMLin($fetch_lineage, ForceArray => ["LinkSet"]);
			
			my @linkSet = @{$doc_link->{"LinkSet"}};
					
			foreach my $link(@linkSet){
				my $protID = $link->{"IdList"}->{"Id"};
				if (exists $link->{"LinkSetDb"}){
					# modified in v.1.6
					if (ref $link->{"LinkSetDb"}->{"Link"} eq 'HASH'){
						my $geneID = $link->{"LinkSetDb"}->{"Link"}->{"Id"};
						$linkGene{$protID}{"geneID"} = $geneID;
						$geneIDlist{$geneID} .= $protID.";";
					} elsif (ref $link->{"LinkSetDb"}->{"Link"} eq 'ARRAY'){
						my @geneSet = @{$link->{"LinkSetDb"}->{"Link"}};
						my @geneID;
						foreach my $geneSet (@geneSet){
							push (@geneID, $geneSet->{"Id"});
							$geneIDlist{$geneSet->{"Id"}} .= $protID.";";
						}
						$linkGene{$protID}{"geneID"} = join(",", @geneID);
					} else {
						die "\nERROR: problem with this protein: $protID. Please contact me (tetsufmbio\@gmail.com)";
					}
					
				} else {
					$linkGene{$protID}{"geneID"} = "NULL";
					$linkGene{$protID}{"geneName"} = "NULL";
					push(@giObsolete, $protID);
				}
				
			}
						
			sleep 1;
			
		} while ($n < $#gilist);
	}
	
	$n = -1;
	$m = -25;
	if (scalar @giObsolete > 0){
		do {
			$n = $n + 25;
			$m = $m + 25;
			$n = $#giObsolete if ($n > $#giObsolete);
			
			my $url_fetch_seq = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?tool=taxontree&email=$email&db=protein&retmode=xml&rettype=gp&id=".join("&id=",@giObsolete[$m .. $n]);
			my $link_xml = retrieveEFetch($url_fetch_seq);;
			my @eachXML = split("</GBSeq>", $link_xml);
			foreach my $eachXML(@eachXML){
				if ($eachXML =~ m/<GBQualifier_value>GeneID:/){
					$eachXML =~ /<GBSeqid>gi\|(\d+)<\/GBSeqid>/;
					my $gi = $1;
					$eachXML =~ /\<GBQualifier_value\>GeneID\:(\d+)\<\/GBQualifier_value\>/;
					my $geneID = $1;
					$linkGene{$gi}{"geneID"} = $geneID;
					$geneIDlist{$geneID} .= $gi.";";
				} else {
					next;
				}
			}
			
			sleep 1;
			
		} while ($n < $#giObsolete);

		foreach my $giObsolete (@giObsolete){
			if ($linkGene{$giObsolete}{"geneID"} eq "NULL"){
				delete $linkGene{$giObsolete};
			}
		}
	
	}

	return \%linkGene;
}

sub retrieveGeneName {
	# Retrieve gene name for each geneID from NCBI
	
	my @geneIDlist = @_;
	my %allGene;
	@allGene{@geneIDlist} = ();
	my %gene2name;
	my $n = -1;
	my $m = -100;
	if (scalar @geneIDlist > 0){
		if ($mysqlInfo{"connection"}){
			if(exists $mysqlInfo{"tables"}{"geneID2geneName"}){
				my $geneTable = $mysqlInfo{"tables"}{"geneID2geneName"};
				my @geneID = @geneIDlist;
				do {
					$n = $n + 100;
					$m = $m + 100;
					$n = $#geneID if ($n > $#geneID);
					my $resultsGene = $wire->query("SELECT * FROM ".$geneTable." where geneID in ('".join("','", @geneID[$m .. $n])."');");
					while (my $row = $resultsGene->next_hash) {
						my $geneID = $row->{geneID};
						my $geneName = $row->{geneName};
						$gene2name{$geneID} = $geneName;
						delete $allGene{$geneID};
					}
				} while ($n < $#geneID);
				$n = -1;
				$m = -100;
			}
		}
	}
	
	@geneIDlist = keys %allGene;
	$n = -1;
	$m = -25;
	if (scalar @geneIDlist > 0){
		do {
			$n = $n + 25;
			$m = $m + 25;
			$n = $#geneIDlist if ($n > $#geneIDlist);
			
			my $url_fetch_seq = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=gene&id=".join(",",@geneIDlist[$m .. $n]);
			my $link_xml = retrieveEFetch($url_fetch_seq);
			
			my $xs1 = XML::Simple->new();
			my $doc_link = $xs1->XMLin($link_xml, ForceArray => ["DocumentSummary"]);
			if (ref $doc_link->{"DocumentSummarySet"}->{"DocumentSummary"} eq 'ARRAY') {
				my @DocumentSummary = @{$doc_link->{"DocumentSummarySet"}->{"DocumentSummary"}};
				foreach my $link(@DocumentSummary){
					my $geneName = $link->{"Name"};
					my $geneID = $link->{"uid"};
					$gene2name{$geneID} = $geneName;
					delete $allGene{$geneID};
				}
			} else {
				print Dumper($doc_link);
			}
			sleep 1;
			
		} while ($n < $#geneIDlist);
	
	}
	
	@geneIDlist = keys %allGene;
	if (scalar @geneIDlist > 0){
		foreach my $geneID(@geneIDlist){
			$gene2name{$geneID} = "NULL";
		}
	}
	#print Dumper(\%linkGene);
	return \%gene2name;
}

sub discardIsoform {
	
	my @subjects_gi = @_;
	my @gilistNoIso;
	my %countedGene;
	
	for (my $i = 0; $i < scalar @subjects_gi; $i++){
		my $subject = $hashCode{"code"}{$subjects_gi[$i]}{"id"};
		if (!(exists $countedGene{$generalInfo{$subject}{"geneID"}})){
			push (@gilistNoIso, $subjects_gi[$i]);
			if ($generalInfo{$subject}{"geneID"} eq "NULL"){
				next;
			} else {
				$countedGene{$generalInfo{$subject}{"geneID"}} = 1;
			}
		}
	}
	
	return @gilistNoIso;
}

sub retrieveSubjectInfo {
	
	my @subjectList = @_;
	print "  Retrieving sequences...  ";
	my $note = 0;
	my %definedID;
	my %missingID;
	my %seqData;
	my @subjectList2;
	@definedID{@subjectList} = ();
	@missingID{@subjectList} = 1;
	my $retrieveWeb = 1;
	
	# retrieve sequences in a local database
	my $fetch_fasta;
	if ($local == 1){
		my $delimiter2 = $delimiter;
		my $posRetrieve = $position;
		my $id_seq_fetch = join("\n", @subjectList);
		
		my $tmp_file = $pid."_tmp_list.txt";
		open(TMP, "> ".$pid."_tmp_list.txt");
		print TMP $id_seq_fetch;
		close TMP;
		my $inputblastdbcmd = $tmp_file;
		my $outputblastdbcmd = $pid."_blastdbcmd.fasta";
		my $defOutputblastdbcmd = $programs{"blastSearch"}{"blastdbcmd"}{"outName"};
		
		my $blastdbcmdCommand = $programs{"blastSearch"}{"blastdbcmd"}{"path"}." ".$programs{"blastSearch"}{"blastdbcmd"}{"command"};
		$blastdbcmdCommand =~ s/#INPUT/$inputblastdbcmd/g;
		$blastdbcmdCommand =~ s/#OUTPUT/$outputblastdbcmd/g;
		$blastdbcmdCommand =~ s/#DB2/$databasecmd/g;
		$defOutputblastdbcmd =~ s/#OUTPUT/$outputblastdbcmd/g;
		
		system($blastdbcmdCommand);
		
		open(BLASTDBCMD, "< $outputblastdbcmd") or die "\nERROR: Can't open the file containing the retrieved sequence from blastdbcmd.\n";
		
		my %seqDataNoVersion;
		while (<BLASTDBCMD>){
			my @line = split(/\|/, $_);
			if ($line[0] ne "N/A"){
				$seqData{$line[0]} = $line[2];
			}
			if ($line[1] ne "N/A"){
				$seqData{$line[1]} = $line[2];
				if (verifyID($line[1]) eq "ncbi_ac"){
					if ($line[1] =~ /\.(\d+)$/){
						my $version = $1;
						$line[1] =~ s/\.\d+$//;
						if (exists $seqDataNoVersion{$line[1]}){
							$seqDataNoVersion{$line[1]} = $version if ($version > $seqDataNoVersion{$line[1]});
						} else {
							$seqDataNoVersion{$line[1]} = $version;
						}
					}
				}
			}
		}
		
		close BLASTDBCMD;
		
		foreach my $id(@subjectList){
			if (exists $seqData{$id}){
				$definedID{$id}{"seq"} = $seqData{$id};
				delete ($missingID{$id});
			} else {
				my $subjectType = verifyID($id);
				if ($subjectType eq "ncbi_ac"){
					if ($id !~ /\.d+$/){
						if (exists $seqDataNoVersion{$id}){
							$definedID{$id}{"seq"} = $seqData{$id.".".$seqDataNoVersion{$id}};
							delete ($missingID{$id});
						}
					}
				} elsif ($subjectType eq "uniprot_id"){
					if (exists $generalInfo{$id}{"id"}){
						my $identifier = $generalInfo{$id}{"id"};
						if (exists $seqData{$identifier}){
							$definedID{$id}{"seq"} = $seqData{$identifier};
							delete ($missingID{$id});
						}
					} 
				}
			}
		}
		
		if (scalar keys %missingID == 0){
			$retrieveWeb = 0;
		} else {
			@subjectList = keys %missingID;
		}
		system("rm ".$pid."_tmp_list.txt");
	}
	
	my (@uniprotAC, @uniprotID, @refseqGI, @refseqAC, @uniprotACIso);
	if ($retrieveWeb == 1){
		# determine if subject is from NCBI or Uniprot:
		foreach my $id(@subjectList){
			chomp $id;
			$id =~ s/\s//g;
			next if ($id =~ m/^$/);
			my $subjectType = verifyID($id);
			if (!$subjectType){
				print "\n    NOTE: Could not recognize $id as NCBI or Uniprot identifier... Identifier discarded.";
				$note = 1;
			} elsif ($subjectType eq "uniprot_id"){
				push(@uniprotID, $id);
			} elsif ($subjectType eq "uniprot_ac"){
				if ($id =~ /-\d+$/){
					push(@uniprotACIso, $id);
				} else {
					push(@uniprotAC, $id);
				}
			} elsif ($subjectType eq "ncbi_gi"){
				next if(exists $subjectInfo{$id}{"seq"});
				push(@refseqGI, $id);
			} elsif ($subjectType eq "ncbi_ac"){
				next if(exists $subjectInfo{$id}{"seq"});
				push(@refseqAC, $id);
			} 
		}
		
		my $type;
		if (scalar @uniprotAC > 0){
			$type = "accession";
			my $refUniprotData = retrieveInfoUniprot(\@uniprotAC, $type);
			foreach my $id(@uniprotAC){
				if (exists $refUniprotData->{$id}){
					$definedID{$id}{"seq"} = $refUniprotData->{$id}->{"seq"};
					delete ($missingID{$id});
				} else {
					print "\n    NOTE: Could not retrieve sequence of $id... This identifier will be discarded.";
					$note = 1;
				}
			}
		}
		if (scalar @uniprotID > 0){
			$type = "mnemonic";
			my $refUniprotData = retrieveInfoUniprot(\@uniprotID, $type);
			foreach my $id(@uniprotID){
				if (exists $refUniprotData->{$id}){
					$definedID{$id}{"seq"} = $refUniprotData->{$id}->{"seq"};
					delete ($missingID{$id});
				} else {
					print "\n    NOTE: Could not retrieve sequence of $id... This identifier will be discarded.";
					$note = 1;
				}
			}
		}
		if (scalar @uniprotACIso > 0){
			$type = "accessioniso";
			my $refUniprotData = retrieveInfoUniprot(\@uniprotACIso, $type);
			foreach my $id(@uniprotACIso){
				if (exists $refUniprotData->{$id}){
					$definedID{$id}{"seq"} = $refUniprotData->{$id}->{"seq"};
					delete ($missingID{$id});
				} else {
					print "\n    NOTE: Could not retrieve sequence of $id... This identifier will be discarded.";
					$note = 1;
				}
			}
		}
		if (scalar @refseqAC + scalar @refseqGI > 0 ){
			my @joinList = (@refseqAC, @refseqGI);
			my $refNCBIData = retrieveInfoNCBI(\@joinList);
			foreach my $id(@refseqGI){
				if (exists $refNCBIData->{$id}){
					$definedID{$id}{"seq"} = $refNCBIData->{$id}->{"seq"};
					delete ($missingID{$id});
				} else {
					print "\n    NOTE: Could not retrieve sequence of $id... This identifier will be discarded.";
					$note = 1;
				}
			}
			foreach my $id(@refseqAC){
				if (exists $refNCBIData->{$id}){
					my $vmax = $refNCBIData->{$id}->{"vmax"};
					$definedID{$id}{"seq"} = $refNCBIData->{$id}->{"v"}->{$vmax}->{"seq"};
					delete ($missingID{$id});
				} elsif ($id =~ /\.(\d+)$/) {
					my $version = $1;
					$id =~ s/\.\d+//;
					if (exists $refNCBIData->{$id}->{"v"}->{$version}->{"seq"}){
						$definedID{$id.".".$version}{"seq"} = $refNCBIData->{$id}->{"v"}->{$version}->{"seq"};
					} else {
						print "\n    NOTE: Could not retrieve sequence of $id... This identifier will be discarded.";
						$note = 1;
					}
				} else {
					print "\n    NOTE: Could not retrieve sequence of $id... This identifier will be discarded.";
					$note = 1;
				}
			}
		}
	}
	
	if ($note == 0){
		print "OK!\n";
	} else {
		print "\n";
	}
	
	return \%definedID;
}

sub pair2pairLCA {
	
	# Retrive lineage of each txid and determine the LCA in each pair of txid.
	# input: an array containing txid.
	# return: a hash having txid as key, with information about the name, lineage, lca and lcaN of each txid.
	print "  Determining LCA...\n";
	my @txid_list = @_;
	my @txidRetrieve = @txid_list;
	my %map_info;
	my $n = -1;
	my $m = -50;
	my $fetch_lineage;
	my @taxSimple_ranks = (
		"superkingdom",
		"kingdom",
		"phylum",
		"subphylum",
		"superclass",
		"class",
		"subclass",
		"superorder",
		"order",
		"suborder",
		"superfamily",
		"family",
		"subfamily",
		"genus",
		"subgenus",
		"species",
		"subspecies",
	);
	
	my %ncbi_all_ranks = (
		"no rank" => -1,
	);
	my %rev_ncbi_all_ranks = ( 
		-1 => "no rank",
	);
	my %taxSimple_ranks;
	
	if ($mysqlInfo{"connection"}){
		if (exists $mysqlInfo{"tables"}{"taxallnomy_rank"} and exists $mysqlInfo{"tables"}{"taxonomy"}){
			print "    Retrieving taxonomy info from local database...";

			my $rankTable = $mysqlInfo{"tables"}{"taxallnomy_rank"};
			my $taxonomyTable = $mysqlInfo{"tables"}{"taxonomy"};
			my $resultsRanks = $wire->query("SELECT * FROM ".$rankTable." ORDER BY ".$rankTable.".order");
			while (my $row = $resultsRanks->next_array) {
				my @row = @$row;
				$row[0] =~ s/ /_/g;
				$taxSimple_ranks{$row[3]} = $row[4];
				$ncbi_all_ranks{$row[0]} = $row[1];
				$rev_ncbi_all_ranks{$row[1]} = $row[0];
			}
			my %retrieveName;
			my %missingTax = map { $_ => 1 } @txidRetrieve;
			my $n = -1;
			my $m = -100;
			do {
				$n = $n + 100;
				$m = $m + 100;
				$n = $#txidRetrieve if ($n > $#txidRetrieve);
				my $results = $wire->query("SELECT * FROM ".$taxonomyTable." where txid in ('".join("','", @txidRetrieve[$m .. $n])."');");
				while (my $row = $results->next_hash) {
					my $txid = $row->{txid};
					my $lineage = $row->{lineage};
					my $sciname = $row->{sciname};
					my @lineage_all = split(";", $lineage);
					my @lineage;
					my @ranks;
					foreach my $level(@lineage_all){
						my ($name, $rank) = split(/:([^:]+)$/, $level);
						$name =~ s/,//g;
						$rank = $rev_ncbi_all_ranks{$rank};
						push (@lineage, $name);
						push (@ranks, $rank);
						$retrieveName{$name} = -1;
					}

					$map_txid{"txids"}{$txid}{"rank"} = \@ranks;
					$map_txid{"txids"}{$txid}{"lineage"} = \@lineage;
					$map_txid{"txids"}{$txid}{"name"} = $sciname;
					delete $missingTax{$txid};
				}
				
			} while ($n < $#txidRetrieve);
			
			$n = -1;
			$m = -100;
			my @retrieveName = keys %retrieveName;
			do {
				$n = $n + 100;
				$m = $m + 100;
				$n = $#retrieveName if ($n > $#retrieveName);
				my $results = $wire->query("SELECT txid,sciname FROM ".$taxonomyTable." where txid in ('".join("','", @retrieveName[$m .. $n])."');");
				while (my $row = $results->next_hash) {
					my $sciname = $row->{sciname};
					my $txid = $row->{txid};
					$retrieveName{$txid} = $sciname;
				}
			} while ($n < $#retrieveName);
			
			foreach my $txid(keys %{$map_txid{"txids"}}){
				if (exists $map_txid{"txids"}{$txid}{"lineage"}){
					my @lineage = @{$map_txid{"txids"}{$txid}{"lineage"}};
					my @lineageName;
					foreach my $code(@lineage){
						my $name = $retrieveName{$code};
						push (@lineageName, $name);
					}
					$map_txid{"txids"}{$txid}{"lineageName"} = \@lineageName;
				}
			}
			
			if (scalar keys %missingTax > 0){
				print "\n    Some txids  (".scalar (keys %missingTax).") was not found in local database.\n  Retrieving from the web.";
			} else {
				print "  OK!\n";
			}
			@txidRetrieve = keys %missingTax;	
		}
		
	}
	
	if (scalar @txidRetrieve > 0){
		if ($internetConnection){
			print "    Retrieving taxonomy info from web...";
			$n = -1;
			$m = -50;
			do {
				
				$n = $n + 50;
				$m = $m + 50;
				$n = $#txidRetrieve if ($n > $#txidRetrieve);
				my $url_fetch_seq = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=taxonomy&id=".join(",",@txidRetrieve[$m .. $n]);
				my $fetch_lineage = retrieveEFetch($url_fetch_seq);
				
				my $xs2 = XML::Simple->new();
				my $doc_lineage = $xs2->XMLin($fetch_lineage, ForceArray => ["Taxon"], KeepRoot => 1);
				my @taxaSet = @{$doc_lineage->{"TaxaSet"}->{"Taxon"}};
				
				foreach my $taxa(@taxaSet){
					my $txid;
					if (exists $taxa->{"AkaTaxIds"}){
						if (ref $taxa->{"AkaTaxIds"} eq 'ARRAY'){
							die "\nERROR: Problems with obsolete taxonomy ID, please report me this bug (tetsufmbio\@gmail.com).\n";
						} else {
							$txid = $taxa->{"AkaTaxIds"}->{"TaxId"};
						}
					} else {
						$txid = $taxa->{"TaxId"};
					}
					my $lineage = $taxa->{"Lineage"};
					my @lineageEx;
					$map_txid{"txids"}{$txid}{"name"} = $taxa->{"ScientificName"};
					# modified in v.1.6
					if (exists ($taxa->{"LineageEx"})){
						my $lineage = $taxa->{"Lineage"};
						$lineage =~ s/,//g;
						my @lineage = split("; ",$lineage);
						push (@lineage, $taxa->{"ScientificName"});
						unshift (@lineage, "Root");
						
						$map_txid{"txids"}{$txid}{"lineageName"} = \@lineage;
						my @ranks;
						my @lineageID;
						@lineageEx = @{$taxa->{"LineageEx"}->{"Taxon"}};
						foreach my $lineageEx (@lineageEx){
							my %singleLineageEx = %$lineageEx;
							push (@ranks, $singleLineageEx{"Rank"});
							push (@lineageID, $singleLineageEx{"TaxId"});
						}
						unshift (@ranks, "no rank");
						unshift (@lineageID, "1");
						push (@ranks, $taxa->{"Rank"});
						push (@lineageID, $taxa->{"TaxId"});
						$map_txid{"txids"}{$txid}{"rank"} = \@ranks;
						$map_txid{"txids"}{$txid}{"lineage"} = \@lineageID;
					} else {
						my @ranks;
						my @lineage;
						my @lineageID;
						if ($txid == 1){
							# root
							unshift (@ranks, "no rank");
							push (@lineage, "Root");
							push (@lineageID, 1);
						} else {
							# cellular organism
							unshift (@ranks, "no rank");
							push (@ranks, $taxa->{"Rank"});
							push (@lineage, $taxa->{"ScientificName"});
							push (@lineageID, $taxa->{"TaxId"});
							unshift (@lineage, "Root");					
							unshift (@lineageID, 1);		
						}
						$map_txid{"txids"}{$txid}{"rank"} = \@ranks;
						$map_txid{"txids"}{$txid}{"lineage"} = \@lineageID;
						$map_txid{"txids"}{$txid}{"lineageName"} = \@lineage;
					}
				}
			} while ($n < $#txidRetrieve);
			print "  OK!\n";
		} else {
			print "\n    NOTE: no internet connection. Txid with missing info will be discarded from the analysis.\n";
		}
	}
	# verify if all txid information was retrieved
	
	foreach my $txid (@txid_list){
		if (!(exists $map_txid{"txids"}{$txid}{"rank"})){
			print "\nNOTE: Could not retrieve info from txid: $txid.\n";
			delete $map_txid{"txids"}{$txid};
			$missingTxid{$txid} = 1;
		}
	}
	@txid_list = keys %{$map_txid{"txids"}};
	
	# taxallnomy
	%missingTaxTN = map { $_ => 1 } @txid_list;
	
	if ($mysqlInfo{"connection"}){
		if (exists $mysqlInfo{"tables"}{"taxallnomy_rank"} and exists $mysqlInfo{"tables"}{"taxallnomy_lin"} and exists $mysqlInfo{"tables"}{"taxonomy"}){
			my $taxallnomyLinTable = $mysqlInfo{"tables"}{"taxallnomy_lin"};
			my $taxonomyTable = $mysqlInfo{"tables"}{"taxonomy"};
			print "    Retrieving taxallnomy info from local database...\n";
			$n = -1;
			$m = -100;
			my %names2recover;
			do {
					
				$n = $n + 100;
				$m = $m + 100;
				$n = $#txid_list if ($n > $#txid_list);
				my $results = $wire->query("SELECT * FROM ".$taxallnomyLinTable." where txid in (".join(",",@txid_list[$m .. $n]).");");
				while (my $row = $results->next_hash) {
					my $txid = $row->{txid};
					my @lineage;
					for(my $p = 0; $p < scalar @taxSimple_ranks; $p++){
						my $name = $row->{$taxSimple_ranks[$p]};
						push(@lineage, $name);
						$name =~ /(\d+)\./;
						my $code = $1;
						$names2recover{$code} = 1;
					}
					unshift (@lineage, "1.000");
					$map_txid{"txids"}{$txid}{"lineageTaxSimpleN"} = \@lineage;
					delete $missingTaxTN{$txid};
				}
			} while ($n < $#txid_list);
			
			my @names2recover = keys %names2recover;
			$n = -1;
			$m = -100;

			do {
					
				$n = $n + 100;
				$m = $m + 100;
				$n = $#names2recover if ($n > $#names2recover);
				my $results = $wire->query("SELECT txid,sciname FROM ".$taxonomyTable." where txid in (".join(",",@names2recover[$m .. $n]).");");
				
				while (my $row = $results->next_hash) {
					my $txid = $row->{txid};
					my $name = $row->{sciname};
					$names2recover{$txid} = $name;
				}
			} while ($n < $#names2recover);
			$names2recover{1} = "Root";
			my @rankArray = @taxSimple_ranks;
			unshift(@rankArray, "Root");
			foreach my $txidTax(keys %{$map_txid{"txids"}}){
				next if (!exists $map_txid{"txids"}{$txidTax}{"lineageTaxSimpleN"});
				my $lineageArrayref = $map_txid{"txids"}{$txidTax}{"lineageTaxSimpleN"};
				my @lineageArray = @$lineageArrayref;
				my @lineageName;
				for (my $i = 0; $i <= $#lineageArray; $i++) {
					my $name = $lineageArray[$i];
					$name =~ /(\d+)\.(\d+)/;
					my $taxon = $names2recover{$1};
					my $code = $2;
					if($code eq "000"){
						push(@lineageName, $taxon);
					} else {
						$code =~ /(\d{2})(\d{1})/;
						my $rankCode = $taxSimple_ranks{$1};
						if ($code =~ /1$/){
							$taxon = $rankCode."_".$taxon;
						} elsif ($code =~ /2$/){
							$taxon = $rankCode."_of_".$taxon;
						} elsif ($code =~ /3$/){
							$taxon = $rankCode."_in_".$taxon;
						}
						push(@lineageName, $taxon);
					}
				}
				#unshift(@lineageName, "Root");
				$map_txid{"txids"}{$txidTax}{"lineageTaxSimple"} = \@lineageName;
				$map_txid{"txids"}{$txidTax}{"rankTaxSimple"} = \@rankArray;
			}
		}
	} 
	
	if(scalar(keys %missingTaxTN > 0)){
		my @txid_list2 = keys %missingTaxTN;
		%missingTaxTN = ();
		%missingTaxTN = map { $_ => 1 } @txid_list2;
		$n = -1;
		$m = -50;
		if ($internetConnection){
			print "    Retrieving taxallnomy info from web...";
			my @retrieveTN;
			do {
					
				$n = $n + 50;
				$m = $m + 50;
				$n = $#txid_list2 if ($n > $#txid_list2);
				my $url_fetch_seq = "http://bioinfo.icb.ufmg.br/cgi-bin/taxallnomy/taxallnomy_multi.pl?txid=".join(",",@txid_list2[$m .. $n])."&rank=custom&srank=".join(",", @taxSimple_ranks);
				my $fetch_lineage = retrieveEFetch($url_fetch_seq);
				
				my @fetch_lineage = split(/\n/, $fetch_lineage);
				my @ranks = @taxSimple_ranks;
				unshift (@ranks, "Root");
				for(my $o = 2; $o < scalar @fetch_lineage; $o++){
					my $lineage = $fetch_lineage[$o];
					chomp $lineage;
					next if ($lineage =~ /^$/);
					my ($txid, @lineage) = split(/\t/, $lineage);
					if ($lineage =~ /taxid not found in our database./){
						next;
					} else {
						unshift (@lineage, "Root");
						$map_txid{"txids"}{$txid}{"rankTaxSimple"} = \@ranks;
						$map_txid{"txids"}{$txid}{"lineageTaxSimple"} = \@lineage;
						push(@retrieveTN, $txid);
					}
				}
				
			} while ($n < $#txid_list2);
			
			$n = -1;
			$m = -50;
			
			do {
				$n = $n + 50;
				$m = $m + 50;
				$n = $#retrieveTN if ($n > $#retrieveTN);
				my $url_fetch_seq = "http://bioinfo.icb.ufmg.br/cgi-bin/taxallnomy/taxallnomy_multi.pl?txid=".join(",",@retrieveTN[$m .. $n])."&type=number&rank=custom&srank=".join(",", @taxSimple_ranks);
				my $fetch_lineage = retrieveEFetch($url_fetch_seq);
				
				my @fetch_lineage = split(/\n/, $fetch_lineage);
				for(my $o = 2; $o < scalar @fetch_lineage; $o++){
					my $lineage = $fetch_lineage[$o];
					chomp $lineage;
					next if ($lineage =~ /^$/);
					my ($txid, @lineage) = split(/\t/, $lineage);
					if ($lineage =~ /taxid not found in our database./){
						next;
					} else {
						unshift (@lineage, "1.000");
						$map_txid{"txids"}{$txid}{"lineageTaxSimpleN"} = \@lineage;
						delete $missingTaxTN{$txid};
					}
				}
				
			} while ($n < $#retrieveTN);
			print "  OK!\n";
		} 	
	}
	
	if(scalar(keys %missingTaxTN) > 0){
		foreach my $txid(keys %missingTaxTN){
			print "\n    NOTE: Could not retrieve info from taxallnomy of this txid: $txid.\n";
			delete $map_txid{"txids"}{$txid};
			$missingTxid{$txid} = 1;
		}
	}
	
	@txid_list = keys %{$map_txid{"txids"}};
	
	## pair2pairLCA
	$map_txid{"minLCA"} = 100;
	$map_txid{"minLCATaxSimple"} = 100;
	
	for (my $i = 0; $i < scalar @txid_list; $i++){
		print $txid_list[$i] if (!$map_txid{"txids"}{$txid_list[$i]}{"lineage"});
		my @lineage1 = @{$map_txid{"txids"}{$txid_list[$i]}{"lineage"}};
		my @lineage1name = @{$map_txid{"txids"}{$txid_list[$i]}{"lineageName"}};
		my @lineageTS1 = @{$map_txid{"txids"}{$txid_list[$i]}{"lineageTaxSimple"}};
		my @rank1 = @{$map_txid{"txids"}{$txid_list[$i]}{"rank"}};
		my @rankTS1 = @{$map_txid{"txids"}{$txid_list[$i]}{"rankTaxSimple"}};
		for (my $j = $i; $j < scalar @txid_list; $j++){
			print $txid_list[$j] if (!$map_txid{"txids"}{$txid_list[$j]}{"lineage"});
			my @lineage2 = @{$map_txid{"txids"}{$txid_list[$j]}{"lineage"}};
			my @lineage2name = @{$map_txid{"txids"}{$txid_list[$j]}{"lineageName"}};
			my @lineageTS2 = @{$map_txid{"txids"}{$txid_list[$j]}{"lineageTaxSimple"}};
			my $min_lineage = (scalar @lineage1, scalar @lineage2)[scalar @lineage1 > scalar @lineage2];
		
			my $lca = 0;
			for (my $k = 0; $k < $min_lineage; $k++){
					
				if ($lineage1[$k] eq $lineage2[$k]){
					$lca++;
				} else {
					last;
				}
			}
			$lca--;
			
			$map_txid{"pair2pairLCA"}{$txid_list[$i]}{"lca"}{$txid_list[$j]} = $lineage1name[$lca]." / ".$rank1[$lca];
			$map_txid{"pair2pairLCA"}{$txid_list[$i]}{"lcaN"}{$txid_list[$j]} = $lca;
			$map_txid{"pair2pairLCA"}{$txid_list[$j]}{"lca"}{$txid_list[$i]} = $lineage1name[$lca]." / ".$rank1[$lca];
			$map_txid{"pair2pairLCA"}{$txid_list[$j]}{"lcaN"}{$txid_list[$i]} = $lca;
			
			# TaxSimple
			$map_txid{"minLCA"} = $lca if ($map_txid{"minLCA"} > $lca);
		
			$min_lineage = scalar @lineageTS1;
			$lca = 0;
			for (my $k = 0; $k < $min_lineage; $k++){
					
				if ($lineageTS1[$k] eq $lineageTS2[$k]){
					$lca++;
				} else {
					last;
				}
			}
			$lca--;
			$map_txid{"pair2pairLCA"}{$txid_list[$i]}{"lcaTaxSimple"}{$txid_list[$j]} = $lineageTS1[$lca]." / ".$rankTS1[$lca];
			$map_txid{"pair2pairLCA"}{$txid_list[$i]}{"lcaNTaxSimple"}{$txid_list[$j]} = $lca;
			$map_txid{"pair2pairLCA"}{$txid_list[$j]}{"lcaTaxSimple"}{$txid_list[$i]} = $lineageTS1[$lca]." / ".$rankTS1[$lca];
			$map_txid{"pair2pairLCA"}{$txid_list[$j]}{"lcaNTaxSimple"}{$txid_list[$i]} = $lca;
			$map_txid{"minLCATaxSimple"} = $lca if ($map_txid{"minLCATaxSimple"} > $lca);
		}
	}
	
	return 1;
}

sub align{
	
	# align sequence
	print "Aligning sequence...\n";
	my $aligner2 = $_[0];
	my $refProts = $_[1];
	my @prots = @$refProts;
	#open (SEQALLTMP, "> ".$pid."_all_seq_tmp.fasta") or die "\nERROR: Can't create ".$pid."_all_seq.fasta.\n";
	open (SEQALL, "> ".$pid."_all_seq.fasta") or die "\nERROR: Can't create ".$pid."_all_seq.fasta.\n";
	
	foreach my $key (@prots){
		
		my $subID = $hashCode{"code"}{$key}{"id"};
		next if (!exists $generalInfo{$subID});
		
		if (!exists $generalInfo{$subID}{"seq"}){
			print "NOTE: Could not retrieve sequence of this accession: $subID.\n";
		} elsif (!$generalInfo{$subID}{"seq"}){
			print "NOTE: Could not retrieve sequence of this accession: $subID.\n";
		} else {
			print SEQALL ">".$key."\n".$generalInfo{$subID}{"seq"}."\n";
			#print SEQALL ">".$generalInfo{$subID}{"name"}."\n".$generalInfo{$subID}{"seq"}."\n";
		}
	}
	close SEQALL;
	#close SEQALLTMP;
	
	my $inputAlignment = $pid."_all_seq.fasta";
	my $outputAlignment = $pid."_seq_aligned.fasta";
	my $defOutputAlignment = $programs{"aligners"}{$aligner2}{"outName"};
	
	my $alignmentCommand = 	$programs{"aligners"}{$aligner2}{"path"}." ".$programs{"aligners"}{$aligner2}{"command"};
	$alignmentCommand =~ s/#INPUT/$inputAlignment/g;
	$alignmentCommand =~ s/#OUTPUT/$outputAlignment/g;
	$defOutputAlignment =~ s/#OUTPUT/$outputAlignment/g;
	$defOutputAlignment =~ s/#INPUT/$inputAlignment/g;
	$alignmentCommand =~ s/#NUMTHREADS/$numThreads/g;
	print "  Software: $aligner2\n  Parameters: ".$programs{"aligners"}{$aligner2}{"command"}."\n";
	system($alignmentCommand);
	
	translateFastaFile($inputAlignment);
	
	print "  Done!\n";
	
	return $defOutputAlignment;
}

sub trimal{
	my $alignmentFile2 = $_[0];
	
	my $inputAlignment = $alignmentFile2;
	my $outputAlignment = $pid."_seq_aligned_trimmed.fasta";
	my $defOutputAlignment = $programs{"trimming"}{$trimProg}{"outName"};
	
	my $alignmentCommand = 	$programs{"trimming"}{$trimProg}{"path"}." ".$programs{"trimming"}{$trimProg}{"command"};
	$alignmentCommand =~ s/#INPUT/$inputAlignment/g;
	$alignmentCommand =~ s/#OUTPUT/$outputAlignment/g;
	$alignmentCommand =~ s/#NUMTHREADS/$numThreads/g;
	$defOutputAlignment =~ s/#OUTPUT/$outputAlignment/g;
	$defOutputAlignment =~ s/#INPUT/$inputAlignment/g;
	
	print "Trimming sequence...\n";
	print "  Software: $trimProg\n  Parameters: ".$programs{"trimming"}{$trimProg}{"command"}."\n";
	system($alignmentCommand);
	
	translateFastaFile($inputAlignment);
	
	print "  Done!\n";
	return $defOutputAlignment;
	
}

sub generateTree {
	# generate phylogenetic tree FastTree
	
	my $alignmentFile2 = $_[0];
	
	my $inputAlignment = $alignmentFile2;
	my $outputAlignment = $pid."_seq.tree";
	my $defOutputAlignment = $programs{"treeReconstruction"}{$treeProg}{"outName"};
	
	my $treeCommand = 	$programs{"treeReconstruction"}{$treeProg}{"path"}." ".$programs{"treeReconstruction"}{$treeProg}{"command"};
	$treeCommand =~ s/#INPUT/$inputAlignment/g;
	$treeCommand =~ s/#OUTPUT/$outputAlignment/g;
	$treeCommand =~ s/#NUMTHREADS/$numThreads/g;
	$defOutputAlignment =~ s/#OUTPUT/$outputAlignment/g;
	$defOutputAlignment =~ s/#INPUT/$inputAlignment/g;
	
	print "Reconstructing phylogenetic tree...\n";
	print "  Software: $treeProg\n  Parameters: ".$programs{"treeReconstruction"}{$treeProg}{"command"}."\n";
	system($treeCommand);
	
	translateFastaFile($inputAlignment);
	
	print "  Done!\n";
	return $defOutputAlignment;
}

sub formatTree{

	# generate nexus file
	
	my $treeFile2 = $_[0];
	my $input = new Bio::TreeIO(-file   => $treeFile2,
								-format => "newick");
	my $tree = $input -> next_tree;
	
	###########################################
	# generate newick
	
	my @leaves = $tree -> get_leaf_nodes();
	
	foreach my $leaf(@leaves){
		my $id = $leaf->id();
		my $defID = $generalInfo{$hashCode{"code"}{$id}{"id"}}{"name"};
		$leaf->id($defID);
	}
	
	my $output = Bio::TreeIO -> new(-format => "newick",
									-file => "> ".$pid."_seq_tree.nwk");
	$output -> write_tree($tree);
	
	############################################
	
	$input = new Bio::TreeIO(-file   => $treeFile2,
								-format => "newick");
	$tree = $input -> next_tree;
	
	# Midpoint rooting.
	
	if ($treeRoot == 1){
		$tree = treeMidpointRoot($tree)
	} elsif ($treeRoot == 2){
		$tree = treeTaxonomicRoot($tree)
	}
	
	# Add tags to the tree branches.
	$tree = treeAddTag($tree);
	
	$output = Bio::TreeIO -> new(-format => "nhx",
									-file => "> ".$pid."_seq_tree.nhx");
	$output -> write_tree($tree);
	
	# convert to NEXUS.
	print "Generating nexus file... ";
	@leaves = $tree -> get_leaf_nodes();
	treeConvertNexus(\@leaves);	
	
	print "\n  Done!\n";
	return 1;
}

sub treeMidpointRoot {

	my ($midtree) = $_[0];
	
	# MidPoint rooting;
	my @leaves2 = $midtree -> get_leaf_nodes();
	print "Rooting tree at midpoint...\n";
	my $maxDistance = -1;
	my $maxDistancePrev = 0;
	my ($maxNode1, $maxNode0) = '';
	#my (@lenNode1, @lenNode0);
	$maxNode1 = rand(scalar @leaves2);
	my $int = 0;
	while ($maxDistance ne $maxDistancePrev or $maxDistance == -1){
		$maxDistancePrev = $maxDistance;
		$maxNode0 = $maxNode1;
		$maxDistance = -1;
		#@lenNode1 = @lenNode0;
		for(my $i = 0; $i < scalar @leaves2; $i++){
			next if ($maxNode0 == $i);
			my $length = $midtree->distance(-nodes=>[$leaves2[$maxNode0], $leaves2[$i]]);
			if ($maxDistance < $length){
				$maxDistance = $length;
				$maxNode1 = $i;
			}
			#$lenNode0[$i] = $length;
		}
		$maxDistance = sprintf "%.5f", $maxDistance;
		$int++;
	}
	#print "  iteration count: ".$int."; Max distance: ".$maxDistance."\n";
	my $midDistance = $maxDistance/2;
	
	#print "  Leaves with maximum length: ".$leaves2[$maxNode1] -> id()." ".$leaves2[$maxNode0] -> id()."\n";
	
	my @maxNode1 = $midtree -> find_node(-id => $leaves2[$maxNode1] -> id());
	my @maxNode0 = $midtree -> find_node(-id => $leaves2[$maxNode0] -> id());
	$midtree->reroot($maxNode1[0]);
	
	my $ancestor = $maxNode0[0]->ancestor;
	
	my $currentNode = $maxNode0[0];
	my $length = $midtree->distance(-nodes=>[$maxNode0[0], $ancestor]);
	while($length < $midDistance){
		$currentNode = $ancestor;
		$ancestor = $currentNode->ancestor;
		$length = $midtree->distance(-nodes=>[$maxNode0[0], $ancestor]);
	}
	
	my $lengthBranch = $midtree->distance(-nodes=>[$currentNode, $ancestor]);
	my $length_dif = $lengthBranch -($length - $midDistance);
	my $midpt;
	if ($length_dif == 0){
		$midpt = $currentNode;
	} else {
		$midpt = $currentNode->create_node_on_branch(-POSITION=>$length_dif, -FORCE=> 1);
	}
	$midtree->reroot($midpt);
	$midtree->contract_linear_paths();
	print "  Done!\n";
	return ($midtree);
}

sub treeTaxonomicRoot {
	my ($midtree) = $_[0];
	#%generalInfo = %subjectInfo;
	#$generalInfo{$queryInfo{"name"}} = \%queryInfo;
	
	# MidPoint rooting;
	my @leaves2 = $midtree -> get_leaf_nodes();
	print "Searching root considering taxonomy...\n";
	my $maxDistance = -1;
	my $maxDistancePrev = 0;
	my ($maxNode1, $maxNode0) = '';
	#my (@lenNode1, @lenNode0);
	$maxNode1 = rand(scalar @leaves2);
	my $int = 0;
	while ($maxDistance ne $maxDistancePrev or $maxDistance == -1){
		$maxDistancePrev = $maxDistance;
		$maxNode0 = $maxNode1;
		$maxDistance = -1;
		#@lenNode1 = @lenNode0;
		for(my $i = 0; $i < scalar @leaves2; $i++){
			next if ($maxNode0 == $i);
			my $length = $midtree->distance(-nodes=>[$leaves2[$maxNode0], $leaves2[$i]]);
			if ($maxDistance < $length){
				$maxDistance = $length;
				$maxNode1 = $i;
			}
			#$lenNode0[$i] = $length;
		}
		$maxDistance = sprintf "%.5f", $maxDistance;
		$int++;
		last if ($int > 10);
	}
	#print "  iteration count: ".$int."; Max distance: ".$maxDistance."\n";
	if ($maxDistance == 0){
			return($midtree);
	} elsif (scalar @leaves2 < 3){
			return($midtree);
	}

	my $midDistance = $maxDistance/2;
	
	#print "  Leaves with maximum length: ".$leaves2[$maxNode1] -> id()." ".$leaves2[$maxNode0] -> id()."\n";
	my $leaveMaxNode1 = $leaves2[$maxNode1] -> id();
	my $leaveMaxNode0 = $leaves2[$maxNode0] -> id();
	
	my $oldRoot2 = $midtree-> get_root_node();
	my @descendent_root2 = $oldRoot2->each_Descendent;
	my $lackingBS;
	foreach my $descendent_root(@descendent_root2){
		if ($descendent_root -> is_Leaf()){
			next;
		} else {
			$lackingBS = $descendent_root -> id();
		}
	}
	if (!$lackingBS){
		$lackingBS = 1;
	} elsif ($lackingBS eq ""){
		$lackingBS = 1;
	}
	$midtree->reroot($leaves2[$maxNode0]);
	$midtree->contract_linear_paths();
	my @nodes = $leaves2[$maxNode0] -> get_all_Descendents;
	my %hash_lca;
	my %hash_lca_array;
	my %hash_distance;
	my %hash_distance_median;
	my %hash_distance_node;
	my %hash_leaves;
	my %hash_leaves_lca;
	my %hash_leaves_lca_array;
	my %hash_leaves_code;
	my %hash_leaves_id2code;
	my %hash_nodes;
	
	foreach my $leaf2(@leaves2){
		$hash_nodes{$leaf2} = $leaf2;
		my $leafid = $leaf2 -> id();
		$hash_leaves{$leafid} = 1;
		$hash_leaves_code{$leaf2} = $leaf2;
		$hash_leaves_id2code{$leafid} = $leaf2;
		my $minLCA = 100;
		my %hash_lca2;
		foreach my $leaf3(@leaves2){
			my $leafid2 = $leaf3 -> id();
			next if ($leafid2 eq $leafid);
			my $leafid2txid = $hashCode{"code"}{$leafid2}{"txid"};
			foreach my $leaf4(@leaves2){
				my $leafid3 = $leaf4 -> id();
				next if ($leafid3 eq $leafid);
				next if ($leafid3 eq $leafid2);
				my $leafid3txid = $hashCode{"code"}{$leafid3}{"txid"};
				$minLCA = $map_txid{"pair2pairLCA"}{$leafid3txid}{"lcaN"}{$leafid2txid} if ($minLCA > $map_txid{"pair2pairLCA"}{$leafid3txid}{"lcaN"}{$leafid2txid});	
				$hash_lca2{$minLCA} = 1;
				#last if ($minLCA == $map_txid{"minLCA"});
			}
			last;
		}
		
		$hash_leaves_lca{$leafid} = $minLCA;
		my @array_lca = keys %hash_lca2;
		@array_lca = sort { $a <=> $b } @array_lca;
		$hash_leaves_lca_array{$leafid} = \@array_lca;
	}
	my @descendent_root = $leaves2[$maxNode0]->each_Descendent;
	my $root_id = $leaves2[$maxNode0] -> id();
	
	foreach my $descendent_root(@descendent_root){
		$hash_lca{$leaves2[$maxNode0]}{$descendent_root} = $hash_leaves_lca{$root_id};
		$hash_lca_array{$leaves2[$maxNode0]}{$descendent_root} = \@{$hash_leaves_lca_array{$root_id}};
		my $length = $midtree->distance(-nodes=>[$leaves2[$maxNode0], $descendent_root]);
		$hash_distance_median{$leaves2[$maxNode0]}{$descendent_root} = $length;
		$hash_distance{$leaves2[$maxNode0]}{$descendent_root} = $length;
		$hash_distance{$descendent_root}{$leaves2[$maxNode0]} = $length;
	}
	
	while (scalar @descendent_root > 0){
		
		my $node2analyse = shift @descendent_root;
		$hash_nodes{$node2analyse} = $node2analyse;
		my $ancestor = $node2analyse->ancestor;
		my $branchCount = 0;
		my %hash_leaves_tmp = %hash_leaves;
		if (!(exists $hash_distance_node{$ancestor})){
			
			my @descendent = $node2analyse->each_Descendent;
			foreach my $descendent(@descendent){
				my $length2 = $midtree->distance(-nodes=>[$node2analyse, $descendent]);
				$hash_distance{$node2analyse}{$descendent} = $length2;
				$hash_distance{$descendent}{$node2analyse} = $length2;
				
				my $lcaMin = 100;
				if ($descendent -> is_Leaf()){
					my $leafid = $descendent -> id();
					delete $hash_leaves_tmp{$leafid};
					my $leafidtxid = $hashCode{"code"}{$leafid}{"txid"};
					$lcaMin = $map_txid{"pair2pairLCA"}{$leafidtxid}{"lcaN"}{$leafidtxid};
					$hash_lca{$node2analyse}{$descendent} = $lcaMin;
					$hash_lca{$descendent}{$node2analyse} = $hash_leaves_lca{$leafid};
					$hash_lca_array{$descendent}{$node2analyse} = \@{$hash_leaves_lca_array{$leafid}};
					$hash_distance_median{$node2analyse}{$descendent} = $length2;
					my @distances;
					$hash_distance_node{$node2analyse}{"leaves"}{$hash_leaves_id2code{$leafid}}{"distance"} = $length2;
					$hash_distance_node{$node2analyse}{"leaves"}{$hash_leaves_id2code{$leafid}}{"group"} = $branchCount;
					$hash_distance_node{$node2analyse}{"branch"}{$descendent} = $branchCount;
					$branchCount++;
				} else {
					push (@descendent_root, $descendent);
					my @subNodes = $descendent -> get_all_Descendents;
					my $refLeaf = "NULL";
					my @median_set;
					my %hash_lca_set;
					foreach my $subLeaves(@subNodes){
						if (!$subLeaves -> is_Leaf()){
							next;
						}
						my $leafid = $subLeaves -> id();
						delete $hash_leaves_tmp{$leafid};
						my $leafidtxid = $hashCode{"code"}{$leafid}{"txid"};
						my $length3 = $midtree->distance(-nodes=>[$node2analyse, $subLeaves]);
						push (@median_set, $length3);
						$hash_distance_node{$node2analyse}{"leaves"}{$hash_leaves_id2code{$leafid}}{"distance"} = $length3;
						$hash_distance_node{$node2analyse}{"leaves"}{$hash_leaves_id2code{$leafid}}{"group"} = $branchCount;
						if ($refLeaf eq "NULL"){
							$refLeaf = $leafid;
							$lcaMin = $map_txid{"pair2pairLCA"}{$leafidtxid}{"lcaN"}{$leafidtxid};
						} else {
							my $lca = $map_txid{"pair2pairLCA"}{$leafidtxid}{"lcaN"}{$leafidtxid};
							$hash_lca_set{$lca} = 1;
							if ($lcaMin > $lca){
								$lcaMin = $lca;
							}
						}
					}
					@median_set = sort { $a <=> $b } @median_set;
					if(scalar @median_set % 2 == 1){
						my $pos = (scalar @median_set + 1)/2;
						$hash_distance_median{$node2analyse}{$descendent} = $median_set[$pos-1];
					} else {
						my $pos = (scalar @median_set)/2;
						$hash_distance_median{$node2analyse}{$descendent} = (($median_set[$pos-1] + $median_set[$pos])/2);
					}
					$hash_distance_node{$node2analyse}{"branch"}{$descendent} = $branchCount;
					$branchCount++;
					$hash_lca{$node2analyse}{$descendent} = $lcaMin;
					my @array_lca_set = keys %hash_lca_set;
					@array_lca_set = sort { $a <=> $b } @array_lca_set;
					$hash_lca_array{$node2analyse}{$descendent} = \@array_lca_set;
				}
			}
			
			my $refLeaf = "NULL";
			my $lcaMin2 = 100;
			my @median_set2;
			my %hash_lca_set2;
			foreach my $leaf_tmp (keys %hash_leaves_tmp){
				my $leafid = $leaf_tmp;
				my $length3 = $midtree->distance(-nodes=>[$node2analyse, $hash_leaves_id2code{$leafid}]);
				my $leafidtxid = $hashCode{"code"}{$leafid}{"txid"};
				push (@median_set2, $length3);
				$hash_distance_node{$node2analyse}{"leaves"}{$hash_leaves_id2code{$leafid}}{"distance"} = $length3;
				$hash_distance_node{$node2analyse}{"leaves"}{$hash_leaves_id2code{$leafid}}{"group"} = $branchCount;
				if ($refLeaf eq "NULL"){
					$refLeaf = $leafid;
					$lcaMin2 = $map_txid{"pair2pairLCA"}{$leafidtxid}{"lcaN"}{$leafidtxid};
				} else {
					my $lca = $map_txid{"pair2pairLCA"}{$leafidtxid}{"lcaN"}{$leafidtxid};
					if ($lcaMin2 > $lca){
						$lcaMin2 = $lca;
					}
					$hash_lca_set2{$lca} = 1;
				}
			}
			@median_set2 = sort { $a <=> $b } @median_set2;
			if(scalar @median_set2 % 2 == 1){
				my $pos = (scalar @median_set2 + 1)/2;
				$hash_distance_median{$node2analyse}{$ancestor} = $median_set2[$pos-1];
			} else {
				my $pos = (scalar @median_set2)/2;
				$hash_distance_median{$node2analyse}{$ancestor} = (($median_set2[$pos-1] + $median_set2[$pos])/2);
			}
			$hash_lca{$node2analyse}{$ancestor} = $lcaMin2;
			$hash_distance_node{$node2analyse}{"branch"}{$ancestor} = $branchCount;
			my @array_lca_set2 = keys %hash_lca_set2;
			@array_lca_set2 = sort { $a <=> $b } @array_lca_set2;
			$hash_lca_array{$node2analyse}{$ancestor} = \@array_lca_set2;
			
		} else {
		
			my $group = $hash_distance_node{$ancestor}{"branch"}{$node2analyse};
			my $length = $hash_distance{$ancestor}{$node2analyse};
			
			my @descendentBranches = $node2analyse->each_Descendent;
			
			foreach my $descendent(@descendentBranches){
				my $length2 = $midtree->distance(-nodes=>[$node2analyse, $descendent]);
				$hash_distance{$node2analyse}{$descendent} = $length2;
				$hash_distance{$descendent}{$node2analyse} = $length2;
				
				my $lcaMin = 100;
				if ($descendent -> is_Leaf()){
					my $leafid = $descendent -> id();
					delete $hash_leaves_tmp{$leafid};
					my $leafidtxid = $hashCode{"code"}{$leafid}{"txid"};
					$lcaMin = $map_txid{"pair2pairLCA"}{$leafidtxid}{"lcaN"}{$leafidtxid};
					$hash_lca{$node2analyse}{$descendent} = $lcaMin;
					$hash_lca{$descendent}{$node2analyse} = $hash_leaves_lca{$leafid};
					$hash_lca_array{$descendent}{$node2analyse} = \@{$hash_leaves_lca_array{$leafid}};
					$hash_distance_median{$node2analyse}{$descendent} = $length2;
					my @distances;
					$hash_distance_node{$node2analyse}{"leaves"}{$hash_leaves_id2code{$leafid}}{"distance"} = $length2;
					$hash_distance_node{$node2analyse}{"leaves"}{$hash_leaves_id2code{$leafid}}{"group"} = $branchCount;
					$hash_distance_node{$node2analyse}{"branch"}{$descendent} = $branchCount;
					$branchCount++;
				} else {
					push (@descendent_root, $descendent);
					my @subNodes = $descendent -> get_all_Descendents;
					my $refLeaf = "NULL";
					my $refLeafTxid = "NULL";
					my @median_set;
					my %hash_lca_set;
					foreach my $subLeaves(@subNodes){
						if (!$subLeaves -> is_Leaf()){
							next;
						}
						my $leafid = $subLeaves -> id();
						delete $hash_leaves_tmp{$leafid};
						my $leafidtxid = $hashCode{"code"}{$leafid}{"txid"};
						my $length3 = $hash_distance_node{$ancestor}{"leaves"}{$hash_leaves_id2code{$leafid}}{"distance"} - $length;
						push (@median_set, $length3);
						$hash_distance_node{$node2analyse}{"leaves"}{$hash_leaves_id2code{$leafid}}{"distance"} = $length3;
						$hash_distance_node{$node2analyse}{"leaves"}{$hash_leaves_id2code{$leafid}}{"group"} = $branchCount;
						
						if ($refLeaf eq "NULL"){
							$refLeaf = $leafid;
							$refLeafTxid = $hashCode{"code"}{$refLeaf}{"txid"};
							$lcaMin = $map_txid{"pair2pairLCA"}{$leafidtxid}{"lcaN"}{$leafidtxid};
						} else {
							my $lca = $map_txid{"pair2pairLCA"}{$leafidtxid}{"lcaN"}{$refLeafTxid};
							if ($lcaMin > $lca){
								$lcaMin = $lca;
							}
							$hash_lca_set{$lca} = 1;
						}
					}
					@median_set = sort { $a <=> $b } @median_set;
					if(scalar @median_set % 2 == 1){
						my $pos = (scalar @median_set + 1)/2;
						$hash_distance_median{$node2analyse}{$descendent} = $median_set[$pos-1];
					} else {
						my $pos = (scalar @median_set)/2;
						$hash_distance_median{$node2analyse}{$descendent} = (($median_set[$pos-1] + $median_set[$pos])/2);
					}
					$hash_distance_node{$node2analyse}{"branch"}{$descendent} = $branchCount;
					$branchCount++;
					$hash_lca{$node2analyse}{$descendent} = $lcaMin;
					my @array_lca_set = keys %hash_lca_set;
					@array_lca_set = sort { $a <=> $b } @array_lca_set;
					$hash_lca_array{$node2analyse}{$descendent} = \@array_lca_set;
				}
			}
			
			my @medianSetAncestor;
			my $refLeaf = "NULL";
			my $refLeafTxid = "NULL";
			my $lcaMin2 = 100;
			$hash_distance_node{$node2analyse}{"branch"}{$ancestor} = $branchCount;
			my %hash_lca_set2;
			foreach my $leaf_tmp (keys %hash_leaves_tmp){
				my $leafid = $leaf_tmp;
				my $leafidtxid = $hashCode{"code"}{$leafid}{"txid"};
				my $length3 = $hash_distance_node{$ancestor}{"leaves"}{$hash_leaves_id2code{$leafid}}{"distance"} + $length;
				push (@medianSetAncestor, $length3);
				$hash_distance_node{$node2analyse}{"leaves"}{$hash_leaves_id2code{$leafid}}{"distance"} = $length3;
				$hash_distance_node{$node2analyse}{"leaves"}{$hash_leaves_id2code{$leafid}}{"group"} = $branchCount;
				if ($refLeaf eq "NULL"){
					$refLeaf = $leafid;
					$refLeafTxid = $hashCode{"code"}{$refLeaf}{"txid"};
					$lcaMin2 = $map_txid{"pair2pairLCA"}{$leafidtxid}{"lcaN"}{$leafidtxid};
				} else {
					my $lca = $map_txid{"pair2pairLCA"}{$leafidtxid}{"lcaN"}{$refLeafTxid};
					if ($lcaMin2 > $lca){
						$lcaMin2 = $lca;
					}
					$hash_lca_set2{$lca} = 1;
				}
			}
			$hash_lca{$node2analyse}{$ancestor} = $lcaMin2;
			if(scalar @medianSetAncestor % 2 == 1){
				my $pos = (scalar @medianSetAncestor + 1)/2;
				$hash_distance_median{$node2analyse}{$ancestor} = $medianSetAncestor[$pos-1];
			} else {
				my $pos = (scalar @medianSetAncestor)/2;
				$hash_distance_median{$node2analyse}{$ancestor} = (($medianSetAncestor[$pos-1] + $medianSetAncestor[$pos])/2);
			}
			my @array_lca_set2 = keys %hash_lca_set2;
			@array_lca_set2 = sort { $a <=> $b } @array_lca_set2;
			$hash_lca_array{$node2analyse}{$ancestor} = \@array_lca_set2;
		}
	}
	
	my %hash_node_bs;
	foreach my $nodeLca(keys %hash_lca){
		my @nodeLCA;
		foreach my $nodeLca2(keys %{$hash_lca{$nodeLca}}){
			push (@nodeLCA, $hash_lca{$nodeLca}{$nodeLca2});
		}
		#$hash_nodes{$nodeLca} -> add_tag_value("lcaNode",join(";", @nodeLCA));
		if ($hash_nodes{$nodeLca} -> is_Leaf()){
			$hash_node_bs{$nodeLca} = 1;
		} else {
			if ($hash_nodes{$nodeLca} -> id()){
				my $bs = $hash_nodes{$nodeLca} -> id();
				if ($bs eq $leaves2[$maxNode0] -> id()){
					$hash_node_bs{$nodeLca} = 0;
				} else {
					$hash_node_bs{$nodeLca} = $bs;
				}
			} else {
				$hash_node_bs{$nodeLca} = $lackingBS;
			}
		}
	}

	my %hash_ok;
	my %hash_result;
	my $total_branch_length = $midtree -> total_branch_length;
	my $maxLength = 0;
	my @LCAcount;
	my @MEDIANcount;

	foreach my $element1(keys %hash_distance){
		foreach my $element2(keys %{$hash_distance{$element1}}){
			if (exists $hash_ok{$element1}{$element2}){
				next;
			} else {
				my @nodes2analyse;
				push(@nodes2analyse, $element1);
				push(@nodes2analyse, $element2);
				my %analysedNodes;
				$analysedNodes{$element2} = 1;
				$analysedNodes{$element1} = 1;
				my $lcaCount = 0;
				my @lcaCount;				
				my $medianCount = 0;
				
				while(scalar @nodes2analyse > 0){
					my $node = shift @nodes2analyse;
					next if (scalar (keys %{$hash_distance{$node}}) < 2); # next if leaf;
					my $minLCA;
					my $minLCANode;
					my $median;
					my @lcaSet;
					my @medianSet;
					my @lcaSetNode;
					my $lcaArray;
					my @lcaArraySet;
					my $count = 0;
					my $refDistance;
					foreach my $subNode (keys %{$hash_distance{$node}}){
						if (exists $analysedNodes{$subNode}){ # ancestral node
							$minLCA = $hash_lca{$subNode}{$node};
							$minLCANode = $hash_lca{$node}{$subNode};
							$median = $hash_distance_median{$node}{$subNode};
							$refDistance = $hash_distance{$subNode}{$node};
							push (@lcaSet, $minLCA);
							push (@lcaSetNode, $minLCANode);
							push (@medianSet, $median);
							$lcaArraySet[$count] = [@{$hash_lca_array{$subNode}{$node}}];
							$lcaArray = $count;
							$count++;
						} else { # descendent node
							$analysedNodes{$subNode} = 1;
							push (@lcaSet, $hash_lca{$subNode}{$node});
							push (@lcaSetNode, $hash_lca{$node}{$subNode});
							push (@medianSet, $hash_distance_median{$node}{$subNode});
							push (@nodes2analyse, $subNode);
							#push (@medianSet, $hash_distance_median{$node}{$subNode});
							$lcaArraySet[$count] = [@{$hash_lca_array{$subNode}{$node}}];
							$count++;
						}
					}
					
					@lcaSet = sort { $a <=> $b } @lcaSet;
					my $lcaMaxAll = $lcaSet[scalar @lcaSet -1];
					my $lcaMinAll = $lcaSet[0];
					my $control2 = 0;
					if ($lcaMaxAll == $lcaMinAll){
						@lcaSetNode = sort { $a <=> $b } @lcaSetNode;
						my $lcaMaxAllNode = $lcaSetNode[scalar @lcaSetNode -1];
						my $lcaMinAllNode = $lcaSetNode[0];
						
						if ($minLCANode == $lcaMinAllNode){
							if ($lcaMinAllNode == $lcaSetNode[1]){
								$control2 = 1
							} else {
								$minLCA = 1;
							}
						} elsif ($lcaMaxAllNode == $lcaMinAllNode){
							$control2 = 1
						} else {
							$minLCA = ($lcaMaxAllNode - $minLCANode)/($lcaMaxAllNode - $lcaMinAllNode);
						}
					} else {
						$minLCA = 1 - ($lcaMaxAll - $minLCA)/($lcaMaxAll - $lcaMinAll);
					}
					
					if ($control2 == 1){
						my @lcaSetResult;
						for(my $p = 0; $p < 4; $p++){
							my @lcaSet2;
							my $control = 0;
							for(my $o = 0; $o < $count; $o++){
								if ($lcaArraySet[$o][$p]){
									push(@lcaSet2, $lcaArraySet[$o][$p]);
								} else {
									$control = 1;
								}
							}
							if ($control == 1){
								last;
							}
							@lcaSet2 = sort { $a <=> $b } @lcaSet2;
							my $lcaMaxAll = $lcaSet2[scalar @lcaSet2 -1];
							my $lcaMinAll = $lcaSet2[0];
							if ($lcaMaxAll == $lcaMinAll){
								for(my $o = 0; $o < $count; $o++){
									if ($lcaArraySet[$o][$p]){
										$lcaSetResult[$o] += 1;
									} else {
										$lcaSetResult[$o] += 0;
									}
								}
							} else {
								for(my $o = 0; $o < $count; $o++){
									if ($lcaArraySet[$o][$p]){
										$lcaSetResult[$o] += 1 - ($lcaMaxAll - $lcaArraySet[$o][$p])/($lcaMaxAll - $lcaMinAll);
									} else {
										$lcaSetResult[$o] += 0;
									}
									
								}
							}
						}
						my $minLCA2 = $lcaSetResult[$lcaArray];
						@lcaSetResult = sort { $a <=> $b } @lcaSetResult;
						my $lcaMaxAll2 = $lcaSetResult[scalar @lcaSetResult -1];
						my $lcaMinAll2 = $lcaSetResult[0];
						if ($lcaMaxAll2 == $lcaMinAll2){
							$minLCA2 = 1;
						} else {
							$minLCA2 = 1 - ($lcaMaxAll2 - $minLCA2)/($lcaMaxAll2 - $lcaMinAll2);
						}
						$minLCA = $minLCA2;
					}
					
					
					@medianSet = sort { $a <=> $b } @medianSet;
					my $medianMaxAll = $medianSet[scalar @medianSet -1];
					my $medianMinAll = $medianSet[0];
					if ($medianMaxAll == $medianMinAll){
						$median = 1;
					} else {
						$median = 1 - ($medianMaxAll - $median)/($medianMaxAll - $medianMinAll);
					}
					$lcaCount += ($minLCA)*$hash_node_bs{$node};
					$medianCount += ($median)*$hash_node_bs{$node};
					push(@lcaCount, ($minLCA)*$hash_node_bs{$node});
					
				}
				
				$hash_ok{$element1}{$element2} = 1;
				$hash_ok{$element2}{$element1} = 1;
				$hash_result{$element1}{$element2}{"lca"} = $lcaCount;
				$hash_result{$element1}{$element2}{"median"} = $medianCount;
				$hash_result{$element1}{$element2}{"count"} = scalar @lcaCount;
				my $mean = $lcaCount/(scalar @lcaCount);
				my $variance;
				foreach my $lcaCount2(@lcaCount){
					$variance += ($lcaCount2 - $mean)**2;
				}
				$variance = $variance/(scalar @lcaCount);
				$hash_result{$element1}{$element2}{"variance"} = $variance;
				push(@LCAcount, $lcaCount);
				push(@MEDIANcount, $medianCount);
				$maxLength = $hash_distance{$element1}{$element2} if ($hash_distance{$element1}{$element2} > $maxLength);
				$hash_result{$element1}{$element2}{"distance"} = $hash_distance{$element1}{$element2};
			}
		}
	}
	open (TABLE,"> ".$pid."_rootScore.tab");
	@LCAcount = sort {$a <=> $b} @LCAcount;
	my $maxLCAcount = $LCAcount[scalar @LCAcount -1];
	my $minLCAcount = $LCAcount[0];
	@MEDIANcount = sort {$a <=> $b} @MEDIANcount;
	my $maxMEDIANcount = $MEDIANcount[scalar @MEDIANcount -1];
	my $minMEDIANcount = $MEDIANcount[0];
	my %hash_score;
	my $maxScore = 0;
	my $selectedDistance = 0;
	my $selectedVariance;
	my %hash_putative_root;
	my %hash_root;
	my @putative_root;
	my $putative_root_count = 0;
	foreach my $element1(keys %hash_result){
		foreach my $element2(keys %{$hash_result{$element1}}){
			my $lcacount = $hash_result{$element1}{$element2}{"lca"};
			my $mediancount = $hash_result{$element1}{$element2}{"median"};
			my $distance = $hash_result{$element1}{$element2}{"distance"};
			my $variance = $hash_result{$element1}{$element2}{"variance"};
			my $count = $hash_result{$element1}{$element2}{"count"};
			my $score;
			my $scoreMedian;
			if ($maxLCAcount != $minLCAcount){
				$score = (($lcacount - $minLCAcount)/($maxLCAcount - $minLCAcount));
			} else {
				$score = $lcacount/$maxLCAcount;
			}
			if ($maxMEDIANcount != $minMEDIANcount){
				$scoreMedian = (($mediancount - $minMEDIANcount)/($maxMEDIANcount - $minMEDIANcount));
			} else {
				$scoreMedian = $mediancount/$maxMEDIANcount;
			}
			$hash_score{$element1}{$element2}{"score"} = $score;
			$hash_score{$element1}{$element2}{"distance"} = $distance;
			$hash_score{$element1}{$element2}{"lca"} = $lcacount;
			
			#if ($score > 0.95 or $scoreMedian > 0.95){
			if ($score > 0.95){
				$putative_root_count++;
				$hash_putative_root{$element1}{$element2}{"lca"} = $score;
				$hash_putative_root{$element1}{$element2}{"median"} = $scoreMedian;
				#$hash_nodes{$element1} -> add_tag_value("PRoot",$score);
				#$hash_nodes{$element2} -> add_tag_value("PRoot",$score);
				my $lcaElement1 = $hash_lca{$element2}{$element1};
				my $lcaElement2 = $hash_lca{$element1}{$element2};
				my $minLcaElement;
				if ($lcaElement1 < $lcaElement2){
					$minLcaElement = $lcaElement1;
				} else {
					$minLcaElement = $lcaElement2;
				}
				$hash_putative_root{$element1}{$element2}{"minLCA"} = $minLcaElement;
			#	my $descendentNode;
			#	my $ancestralNode;
			#	my $oldRoot = $midtree-> get_root_node();
			#	my $rootLength;
			#	if ($midtree->distance(-nodes=>[$hash_nodes{$element1}, $oldRoot]) < $midtree->distance(-nodes=>[$hash_nodes{$element2}, $oldRoot])){
			#		$descendentNode  = $element2; 
			#		$ancestralNode = $element1;
			#		$rootLength = ($lcaElement2/($lcaElement2 + $lcaElement1))*$distance;
			#	} else {
			#		$descendentNode  = $element1; 
			#		$ancestralNode = $element2;
			#		$rootLength = ($lcaElement1/($lcaElement2 + $lcaElement1))*$distance;
			#	}
				print TABLE $lcacount."\t".$score."\t".$scoreMedian."\t".$score*$scoreMedian."\t".$distance."\t".$minLcaElement."\n";
			}
		}
	}
	my %hash_analysed;
	my $bestElement1;
	my $bestElement2;
	my $maxdistance = -1;
	my @score;
	my $maxScoreLcaMedian = 0;
	my $maxLCA = 0;
	foreach my $putative_root2(keys %hash_putative_root){
		foreach my $putative_root3(keys %{$hash_putative_root{$putative_root2}}){
			my $scoreLcaMedian = $hash_putative_root{$putative_root2}{$putative_root3}{"lca"}*$hash_putative_root{$putative_root2}{$putative_root3}{"median"};
			#my $distance = $midtree->distance(-nodes=>[$hash_nodes{$putative_root2}, $hash_nodes{$putative_root3}]);
			my $distance = $hash_putative_root{$putative_root2}{$putative_root3}{"median"};
			
			if ($hash_putative_root{$putative_root2}{$putative_root3}{"lca"} == 1){
				if ($hash_putative_root{$putative_root2}{$putative_root3}{"minLCA"} == $maxLCA){
					if ($maxdistance < $distance){
						$bestElement1 = $putative_root2;
						$bestElement2 = $putative_root3;
						$maxdistance = $distance;
						$maxScoreLcaMedian = $scoreLcaMedian if ($maxScoreLcaMedian < $scoreLcaMedian);
					}
				} elsif ($hash_putative_root{$putative_root2}{$putative_root3}{"minLCA"} > $maxLCA){
					$bestElement1 = $putative_root2;
					$bestElement2 = $putative_root3;
					$maxdistance = $distance;
					$maxLCA = $hash_putative_root{$putative_root2}{$putative_root3}{"minLCA"};
					$maxScoreLcaMedian = $scoreLcaMedian if ($maxScoreLcaMedian < $scoreLcaMedian);
				}
			}
		}
	}
	my $descendentNode;
	my $rootLength;
	my $oldRoot = $midtree-> get_root_node();
	my $proportion;
	if (exists $hash_distance_median{$bestElement1} and exists $hash_distance_median{$bestElement2}){
		# both are internal node
		my $median2 = $hash_distance_median{$bestElement1}{$bestElement2};
		my $median1 = $hash_distance_median{$bestElement2}{$bestElement1};
		$proportion = $median1/($median1 + $median2);
	} elsif (exists $hash_distance_median{$bestElement1}) {
		# bestElement1 is internal node
		my $maxMedian = 0;
		foreach my $node(keys %{$hash_distance_median{$bestElement1}}){
			next if ($node eq $bestElement2);
			$maxMedian = $hash_distance_median{$bestElement1}{$node} if ($hash_distance_median{$bestElement1}{$node} > $maxMedian);
		}
		my $branchLength = $hash_distance{$bestElement1}{$bestElement2};
		my $median2 = $branchLength*0.1;
		$proportion = $maxMedian/($maxMedian + $median2);
	} elsif (exists $hash_distance_median{$bestElement2}) {
		# bestElement2 is internal node
		my $maxMedian = 0;
		foreach my $node(keys %{$hash_distance_median{$bestElement2}}){
			next if ($node eq $bestElement1);
			$maxMedian = $hash_distance_median{$bestElement2}{$node} if ($hash_distance_median{$bestElement2}{$node} > $maxMedian);
		}
		my $branchLength = $hash_distance{$bestElement2}{$bestElement1};
		my $median1 = $branchLength*0.1;
		$proportion = $median1/($maxMedian + $median1);
	}
	
	if (!$hash_nodes{$bestElement1} -> ancestor){
		$descendentNode = $bestElement2;
	} elsif ($hash_nodes{$bestElement1} -> ancestor eq $hash_nodes{$bestElement2}){
		$descendentNode = $bestElement1;
		$proportion = 1 - $proportion;
	} else {
		$descendentNode = $bestElement2;
	}

	my $currentNode3 = $hash_nodes{$descendentNode};
	my $midDistance2 = $maxdistance/2;
	my $ancestor3 = $hash_nodes{$descendentNode}-> ancestor;
	my $length3 = $midtree->distance(-nodes=>[$hash_nodes{$descendentNode}, $ancestor3]);
	my $currentDistance = $length3;
	
	my $midpt3;
	if ($proportion == 0){
		$proportion = 0.1;
	} elsif ($proportion == 1){
		$proportion = 0.9;
	}
	if ($length3 == 0){
		$midpt3 = $currentNode3->create_node_on_branch(-FORCE=>1, -POSITION=>0);
	} else {
		$midpt3 = $currentNode3->create_node_on_branch(-POSITION=>$proportion*$length3);
	}
	
	#$midpt3 = $currentNode3->create_node_on_branch((-POSITION=>$proportion*$length3, -FORCE));
	
	$midtree->reroot($midpt3);
	$midtree->contract_linear_paths();
	#print "  OK!\n";
	return ($midtree);
}

sub treeAddTag {

	# Include taxonomic information in the tree generated by FastTree rewritting the tree in nhx and nexus format.
	# input: a hash reference of %taxSubjects and %map_txid
	# output:

	my ($treeTag) = @_;
	
	my @taxSimple_ranks_map = (
		"01-superkingdom",
		"02-kingdom",
		"03-phylum",
		"04-subphylum",
		"05-superclass",
		"06-class",
		"07-subclass",
		"08-superorder",
		"09-order",
		"10-suborder",
		"11-superfamily",
		"12-family",
		"13-subfamily",
		"14-genus",
		"15-subgenus",
		"16-species",
		"17-subspecies",
	);
	my %taxSimple_ranks_map = (
		"01-superkingdom" => 1,
		"02-kingdom" => 1,
		"03-phylum" => 1,
		"04-subphylum" => 1,
		"05-superclass" => 1,
		"06-class" => 1,
		"07-subclass" => 1,
		"08-superorder" => 1,
		"09-order" => 1,
		"10-suborder" => 1,
		"11-superfamily" => 1,
		"12-family" => 1,
		"13-subfamily" => 1,
		"14-genus" => 1,
		"15-subgenus" => 1,
		"16-species" => 1,
		"17-subspecies" => 1,
	);
	
	# pick distance
	my @leafNodes = $treeTag->get_leaf_nodes;
	my $queryCode = "ID1";
	my $n1 = $treeTag->find_node($queryCode);
	my %distance;
	foreach my $node(@leafNodes) {
		my $results = $treeTag->distance(-nodes=> [$n1, $node]);
		my $node2 = $node->id;
		$distance{$node2} = $results;
	}
	
	# define code for each taxonomy of defined taxsimple ranks
	my %taxSimple_code; # {'rank'}{$rank}{$rank_name} = code
						# {'leaf'}{$leaf}{$rank_name} = code
	my @taxSimple_lineage;
	my @distanceSort = sort { $distance{$a} <=> $distance{$b} } keys %distance;
	if ($distanceSort[0] ne $queryCode){
		unshift(@distanceSort, $queryCode);
	}
	foreach my $leaf(@distanceSort){
		my $leafTxid = $hashCode{"code"}{$leaf}{"txid"};
		my $ref_ranks = $map_txid{"txids"}{$leafTxid}{"lineageTaxSimple"};
		if (!$map_txid{"txids"}{$leafTxid}{"lineageTaxSimple"}){
			print $leaf."\n";
			print $leafTxid."\n";
		}
		my @ranks = @$ref_ranks;
		shift @ranks;
		push (@ranks, $leaf);
		push (@taxSimple_lineage,[@ranks]);
	}

	for (my $j = 0; $j < scalar @{$taxSimple_lineage[0]} - 1; $j++){
		for (my $i = 0; $i < scalar @taxSimple_lineage; $i++){
			if (!(exists $taxSimple_code{"rank"}{$taxSimple_ranks_map[$j]}{$taxSimple_lineage[$i][$j]})){
				$taxSimple_code{"rank"}{$taxSimple_ranks_map[$j]}{$taxSimple_lineage[$i][$j]} = $taxSimple_ranks_map{$taxSimple_ranks_map[$j]};
				$taxSimple_ranks_map{$taxSimple_ranks_map[$j]} += 1;
			}
			$taxSimple_code{"leaf"}{$taxSimple_lineage[$i][scalar @{$taxSimple_lineage[0]} - 1]}{$taxSimple_ranks_map[$j]} = $taxSimple_code{"rank"}{$taxSimple_ranks_map[$j]}{$taxSimple_lineage[$i][$j]};
			$taxSimple_lineage[$i][$j] = $taxSimple_code{"rank"}{$taxSimple_ranks_map[$j]}{$taxSimple_lineage[$i][$j]};
		}
	}
	
	my @leaves = $treeTag -> get_leaf_nodes();
	
	# Add tags on leaves
	foreach my $leaf(@leaves){

		my $leafid = $leaf -> id();
		my $leafTxid = $hashCode{"code"}{$leafid}{"txid"};
		$leaf -> add_tag_value("lca", '"'."(n".$map_txid{"pair2pairLCA"}{$leafTxid}{"lcaN"}{$txidMap}.") ".$map_txid{"pair2pairLCA"}{$leafTxid}{"lca"}{$txidMap}.'"'); 
		my $ref_ranks = $map_txid{"txids"}{$leafTxid}{"lineageTaxSimple"};
		my @ref_ranks = @$ref_ranks;
		shift @ref_ranks;
		my $i = 0;
		foreach my $taxSimpleRank(@taxSimple_ranks_map){
			my $zeroLenght = length(scalar keys %{$taxSimple_code{"rank"}{$taxSimpleRank}});
			my $code = sprintf("%0${zeroLenght}d", $taxSimple_code{"rank"}{$taxSimpleRank}{$ref_ranks[$i]});
			$leaf -> add_tag_value($taxSimpleRank, '"'."(".$code.") ".$ref_ranks[$i].'"');
			$i++;
		}
		
		if (scalar(keys %otherTableHash) > 0){
			foreach my $label(sort keys %otherTableHash){
				my $leafid2 = $hashCode{"code"}{$leafid}{"id"};
				if (exists $otherTableHash{$label}{$generalInfo{$leafid2}{"name"}}){
					$leaf -> add_tag_value($label, '"'.$otherTableHash{$label}{$generalInfo{$leafid2}{"name"}}.'"');
				} else {	
					#$leaf -> add_tag_value($label, 'NULL');
				}
			}
		}
	}
	
	# Coloring branches according to LCA
	my @internal_nodes = ();
	my @nodes = $treeTag -> get_nodes;
	foreach my $node(@nodes) {

		next if ($node -> is_Leaf());
		push (@internal_nodes, $node);
		my @leaves2 = $node -> get_all_Descendents;
		
		my ($value1, $value2);
		my $n = 0;
		
		foreach my $leaves(@leaves2){
				
			if ($leaves -> is_Leaf()){
			
				my $leafid = $leaves -> id();
				$value2 = $leaves -> get_tag_values("lca");  ## <---
				if (!$value2){
					$n = 1;
					last;
				} elsif (!$value1){
					$value1 = $value2;
					next;
				} elsif ($value1 eq $value2){  ## <---
					next;
				} else {
					$n = 1;
					last;
				#	next;
				}
			}
		}
		
		if ($n == 0 && $value1){
			$node -> add_tag_value("lca",$value1);  ## <---
		}
	}

	# Coloring branches according to otherTable
	if (scalar(keys %otherTableHash) > 0){
		foreach my $label(sort keys %otherTableHash){
			foreach my $node(@internal_nodes) {

				my @leaves2 = $node -> get_all_Descendents;
				
				my ($value1, $value2);
				my $n = 0;
				
				foreach my $leaves(@leaves2){
						
					if ($leaves -> is_Leaf()){
					
						my $leafid = $leaves -> id();
						$value2 = $leaves -> get_tag_values($label);  ## <---
						if (!$value2){
							$n = 1;
							last;
						} elsif (!$value1){
							$value1 = $value2;
							next;
						} elsif ($value1 eq $value2){  ## <---
							next;
						} else {
							$n = 1;
							last;
						#	next;
						}
					}
				}
				
				if ($n == 0 && $value1){
					$node -> add_tag_value($label,$value1);  ## <---
				}
			}
		}
	}
	
	# Add bootstrap tag
	foreach my $node(@internal_nodes){

		if ($node -> id()){
			my $bs = $node -> id();
			$node -> add_tag_value("BOOT",$bs);
		}
	}
	
	# Add duplication tags
	my %dupNodes;
	foreach my $node(@internal_nodes){
		my @descendents = $node->each_Descendent;
		my $dup = 0;
		my %species;
		foreach my $descendent(@descendents){
			if ($descendent -> is_Leaf()){
				my $nodeID = $descendent -> id();
				my $leafTaxId = $hashCode{"code"}{$nodeID}{"txid"};
				if (exists ($species{$leafTaxId})){
					$dup = 1;
					last;
				} else {
					$species{$leafTaxId} = 1;
				}
			} else {
				my @leaves2 = $descendent -> get_all_Descendents;
				my %species2;
				foreach my $leaf2(@leaves2){
					if ($leaf2 -> is_Leaf()){
						my $nodeID = $leaf2 -> id();
						my $leafTaxId = $hashCode{"code"}{$nodeID}{"txid"};
						$species2{$leafTaxId} = 1;
					} else {
						next;
					}
				}
				foreach my $keyTax (keys %species2){
					if (exists $species{$keyTax}){
						$dup = 1;
						last;
					} else {
						$species{$keyTax} = 1;
					}
				}
				if ($dup == 1){
					last;
				}
			}
		}
		$node -> add_tag_value("dup",$dup);
		if ($dup == 1){
			$dupNodes{$node} = 1;
		}
	}
	
	# Classify each internal node according to duplication events
	my $root = $treeTag-> get_root_node();
	my @nodes2analyse2 = $root->each_Descendent;
	my @nodes2analyse;
	my %internalNodesDistance;
	my $minDistance = -1;
	foreach my $descendentRoot(@nodes2analyse2){
		my $results = $treeTag->distance(-nodes=> [$n1, $descendentRoot]);
		$internalNodesDistance{$descendentRoot} = $results;
		if ($results < $minDistance or $minDistance == -1){
			$minDistance = $results;
			unshift(@nodes2analyse, $descendentRoot);
		} else {
			push(@nodes2analyse, $descendentRoot);
		}
	}
	
	my %dupNodeCode;
	my %dupNodeLevel;
	$dupNodeCode{$root} = "R";
	$dupNodeLevel{"R"}{"desc"} = {};
	$dupNodeLevel{"R"}{"count"} = 0;
	while (scalar @nodes2analyse != 0){
		my $node2analyse = shift @nodes2analyse;
		my $ancestor = $node2analyse->ancestor;
		if (exists $dupNodes{$ancestor}){
			$dupNodeLevel{$dupNodeCode{$ancestor}}{"count"} += 1;
			$dupNodeCode{$node2analyse} = $dupNodeCode{$ancestor}.".".$dupNodeLevel{$dupNodeCode{$ancestor}}{"count"};
			$dupNodeLevel{$dupNodeCode{$ancestor}}{"desc"}{$dupNodeCode{$node2analyse}} = 1;
		} else {
			$dupNodeCode{$node2analyse} = $dupNodeCode{$ancestor};
		}
		if ($node2analyse -> is_Leaf()){
			next;
		} else {
			my @descendentNodes = $node2analyse->each_Descendent;
			foreach my $descendentNode(@descendentNodes){
				push(@nodes2analyse, $descendentNode);
			}
		}
		my $minDistance2 = -1;
		my @nodes2analyse3;
		foreach my $descendentRoot2(@nodes2analyse){
			my $results2;
			if (exists $internalNodesDistance{$descendentRoot2}){
				$results2 = $internalNodesDistance{$descendentRoot2};
			} else {
				$results2 = $treeTag->distance(-nodes=> [$n1, $descendentRoot2]);
				$internalNodesDistance{$descendentRoot2} = $results2;
			}
			
			if ($results2 < $minDistance2 or $minDistance2 == -1){
				$minDistance2 = $results2;
				unshift(@nodes2analyse3, $descendentRoot2);
			} else {
				push(@nodes2analyse3, $descendentRoot2);
			}
		}
		@nodes2analyse = @nodes2analyse3;
	}
	
	# Add tags for each node according to the rank
	my $taxsimpleLCA = 100;
	foreach my $node(@internal_nodes){
		my @leaves2 = $node -> get_all_Descendents;
		my ($leaf1, $leaf2);
		my $leaf1Txid;
		my $ref_ranks;
		my $lca = 100;
		foreach my $leaves(@leaves2){
			if ($leaves -> is_Leaf()){
				my $leafid = $leaves -> id();
				my $leafTxid = $hashCode{"code"}{$leafid}{"txid"};
				if (!$leaf1){
					$leaf1 = $leafid;
					$leaf1Txid = $hashCode{"code"}{$leaf1}{"txid"};
					$ref_ranks = $map_txid{"txids"}{$leafTxid}{"lineageTaxSimple"};
				} else {
					my $localLCA = $map_txid{"pair2pairLCA"}{$leaf1Txid}{"lcaNTaxSimple"}{$leafTxid};
					$lca = $localLCA if ($localLCA < $lca);
					$taxsimpleLCA = $localLCA if ($localLCA < $taxsimpleLCA);
				}
			}
			last if ($lca == 0);
		}
		my @ref_ranks = @$ref_ranks;
		$lca = scalar @ref_ranks - 1 if ($lca > scalar @ref_ranks - 1);
		for (my $i = 1; $i <= $lca; $i++){
			my $zeroLenght = length(scalar keys %{$taxSimple_code{"rank"}{$taxSimple_ranks_map[$i-1]}});
			my $code = sprintf("%0${zeroLenght}d",$taxSimple_code{"rank"}{$taxSimple_ranks_map[$i-1]}{$ref_ranks[$i]});
			$node -> add_tag_value($taxSimple_ranks_map[$i - 1],'"'."(".$code.") ".$ref_ranks[$i].'"');
		}
	}
	
	# --> make a table classifying each leaf to a taxonomic level

	open (TABLE, "> ".$pid."_taxRankTable.txt") or die;
	my %leaf_rank;
	
	my @rank_analyse_report;
	foreach my $taxRepRank (@taxRepOptions){
		push (@rank_analyse_report, $taxRepRank);
	}
	
	for(my $q = 0; $q < scalar @rank_analyse_report; $q++){
		my $i = $rank_analyse_report[$q];
		my %leaf_code;
		my %node_code;
		my $code2 = 0;
		foreach my $leaf(@leaves){
			my $leafid = $leaf -> id();
			my $leafTxid = $hashCode{"code"}{$leafid}{"txid"};
			my $ref_ranks = $map_txid{"txids"}{$leafTxid}{"lineageTaxSimple"};
			my @ref_ranks = @$ref_ranks;
			$leaf_code{$leafid}{"rank"} = $ref_ranks[$i]; # leaf family
			$leaf_code{$leafid}{"code"} = $code2;
			$leaf_code{$leafid}{"lca"} = $map_txid{"pair2pairLCA"}{$leafTxid}{"lcaN"}{$txidMap};
			$leaf_code{$leafid}{"txid"} = 1;
			$leaf_code{$leafid}{"external"} = 1;
			$leaf_code{$leafid}{"boot"} = 0;
			$leaf_code{$leafid}{"meanDistance"} = $distance{$leafid};
			
			#my $leafAncestor = $leaf -> ancestor;
			$leaf_code{$leafid}{"dupNode"} = $dupNodeCode{$leaf};
			
			$node_code{$code2} = $leaf;
			if ($leafid eq $queryInfo{"name"}){
				$leaf_code{$leafid}{"query"} = 1;
			} else {
				$leaf_code{$leafid}{"query"} = 0;
			}
			if ($leafTxid eq $queryInfo{"txid"}){
				$leaf_code{$leafid}{"queryTax"} = 1;
			} else {
				$leaf_code{$leafid}{"queryTax"} = 0;
			}
			$code2++;
		}
		foreach my $node(@internal_nodes){
			my @leaves3 = $node -> get_all_Descendents;
			my ($leaf1, $leaf2) = '';
			my $leaf1Txid;
			my $ref_ranks;
			my $lca = 100;
			my $countLeaves = 0;
			foreach my $leaves(@leaves3){
				if ($leaves -> is_Leaf()){
					my $leafid = $leaves -> id();
					my $leafTxid = $hashCode{"code"}{$leafid}{"txid"};
					$countLeaves++;
					if ($leaf1 eq ''){
						$leaf1 = $leafid;
						$leaf1Txid = $hashCode{"code"}{$leaf1}{"txid"};
						$ref_ranks = $map_txid{"txids"}{$leafTxid}{"lineageTaxSimple"};
					} else {
						my $localLCA = $map_txid{"pair2pairLCA"}{$leaf1Txid}{"lcaNTaxSimple"}{$leafTxid};
						$lca = $localLCA if ($localLCA < $lca);
					}
				}
				last if ($lca < $i); # family
			}
			next if ($lca < $i); # family
			my @ref_ranks = @$ref_ranks;
			my $lowest_code = 90000;
			my $lowest_lca = 90000;
			my $lowest_dupNode = $dupNodeCode{$node};
			my $largest_speciesDiv = 0;
			my $largest_external = 0;
			my $largest_queryTax = 0;
			my $clusterBoot = 0;
			my $sumDistance = 0;
			my $meanDistance = 0;
			my $clusterQuery = 0;
			my $clusterQueryTax = 0;
			my %speciesDiv;
			foreach my $leaves(@leaves3){
				if ($leaves -> is_Leaf()){
					my $leafid = $leaves -> id();
					my $leafTxid = $hashCode{"code"}{$leafid}{"txid"};
					$sumDistance += $distance{$leafid};
					$lowest_code = $leaf_code{$leafid}{"code"} if ($leaf_code{$leafid}{"code"} < $lowest_code);
					$lowest_lca = $leaf_code{$leafid}{"lca"} if ($leaf_code{$leafid}{"lca"} < $lowest_lca);
					$largest_speciesDiv = $leaf_code{$leafid}{"txid"} if ($leaf_code{$leafid}{"txid"} > $largest_speciesDiv);
					if ($leaf_code{$leafid}{"external"} > $largest_external){
						$largest_external = $leaf_code{$leafid}{"external"};
						$meanDistance = $leaf_code{$leafid}{"meanDistance"};
						$clusterBoot = $leaf_code{$leafid}{"boot"};
					}
					$speciesDiv{$leafTxid} = 1;
					$clusterQuery = 1 if ($leaf_code{$leafid}{"query"} == 1);
					if ($leaf_code{$leafid}{"queryTax"} > $largest_queryTax){
						$largest_queryTax = $leaf_code{$leafid}{"queryTax"};
					}
					$clusterQueryTax++ if ($leafTxid eq $queryInfo{"txid"});
				}
			}
			$largest_speciesDiv = scalar keys %speciesDiv if ($largest_speciesDiv < scalar keys %speciesDiv);
			if (!(exists $node_code{$lowest_code})){
				$node_code{$lowest_code} = $node;
			}
			my $change = 0;
			if ($largest_external < $countLeaves){
				$change = 1;
				$largest_external = $countLeaves;
				$clusterBoot = $node -> id();
				$clusterBoot = 0 if (!$clusterBoot);
				$clusterBoot = 0 if ($clusterBoot eq "");
				$node_code{$lowest_code} = $node;
				$meanDistance = $sumDistance/$countLeaves;
			} 
			if ($largest_queryTax < $clusterQueryTax){
				$largest_queryTax = $clusterQueryTax;
			}
			foreach my $leaves(@leaves3){
				if ($leaves -> is_Leaf()){
					my $leafid = $leaves -> id();
					$leaf_code{$leafid}{"code"} = $lowest_code;
					$leaf_code{$leafid}{"lca"} = $lowest_lca;
					$leaf_code{$leafid}{"txid"} = $largest_speciesDiv;
					$leaf_code{$leafid}{"query"} = $clusterQuery;
					$leaf_code{$leafid}{"queryTax"} = $largest_queryTax;
					$leaf_code{$leafid}{"external"} = $largest_external;
					$leaf_code{$leafid}{"boot"} = $clusterBoot;
					$leaf_code{$leafid}{"meanDistance"} = $meanDistance;
					$leaf_code{$leafid}{"dupNode"} = $lowest_dupNode if ($change == 1);
				}
			}
		}
		## pick ancestor and neighbor
		my %codes2analyse;
		foreach my $leaf(@leaves){
			my $leafid = $leaf -> id();
			$codes2analyse{$leaf_code{$leafid}{"code"}} =  {};
		}
		foreach my $node2analyse(keys %codes2analyse){
			my $currentNode = $node_code{$node2analyse};
			my $ancestorNode = $currentNode -> ancestor;
			if ($ancestorNode){
				my @descendent = $ancestorNode->each_Descendent;
				my %neighborCluster;
				foreach my $descendent(@descendent){
					next if ($descendent eq $currentNode);
					if ($descendent -> is_Leaf()){
						my $leafid = $descendent -> id();
						$neighborCluster{$leaf_code{$leafid}{"code"}} = 1;
					} else {
						my @leaves3 = $descendent -> get_all_Descendents;
						foreach my $leaves(@leaves3){
							if ($leaves -> is_Leaf()){
								my $leafid = $leaves -> id();
								$neighborCluster{$leaf_code{$leafid}{"code"}} = 1;
							}
						}
					}
					
				}
				my @neighbors = sort { $a <=> $b } keys %neighborCluster;
				my $neighbors = join(";", @neighbors);
				$codes2analyse{$node2analyse}{"neighbor"} = $neighbors;
				my $ancestorNeighbor;
				my %ancestorCluster;
				my $secondAncestor = $ancestorNode -> ancestor;
				if ($secondAncestor){
					
						my @descendent2 = $secondAncestor->each_Descendent;
						foreach my $descendent(@descendent2){
							next if ($descendent eq $ancestorNode);
							if ($descendent -> is_Leaf()){
								my $leafid = $descendent -> id();
								$ancestorCluster{$leaf_code{$leafid}{"code"}} = 1;
							} else {
								my @leaves3 = $descendent -> get_all_Descendents;
								foreach my $leaves(@leaves3){
									if ($leaves -> is_Leaf()){
										my $leafid = $leaves -> id();
										$ancestorCluster{$leaf_code{$leafid}{"code"}} = 1;
									}
								}
							}
						}
						my @ancestorNeighbors = sort { $a <=> $b } keys %ancestorCluster;
						my $ancestorNeighbor = join(";", @ancestorNeighbors);
						$codes2analyse{$node2analyse}{"ancestor"} = $ancestorNeighbor;					
				} else {
					$codes2analyse{$node2analyse}{"ancestor"} = "-";
				}
			} else {
				$codes2analyse{$node2analyse}{"ancestor"} = "-";
				$codes2analyse{$node2analyse}{"neighbor"} = "-";
			}
			#print "neighbor: ".$codes2analyse{$node2analyse}{"ancestor"}." ancestor: ".$codes2analyse{$node2analyse}{"ancestor"}."\n";
		}
		
		my %code_control; 	# $code_control{$rank}{"number"}
							# $code_control{$rank}{"code"}{$code}
							# $code_control{$rank}{"count"}{$code}

		foreach my $leaf(sort { $distance{$a} <=> $distance{$b} } keys %distance){
			if (exists ($code_control{$leaf_code{$leaf}{"rank"}}{"number"})){
				if (exists ($code_control{$leaf_code{$leaf}{"rank"}}{"code"}{$leaf_code{$leaf}{"code"}})){
					$code_control{$leaf_code{$leaf}{"rank"}}{"count"}{$leaf_code{$leaf}{"code"}} += 1;
					$leaf_rank{$leaf}{$q} = $leaf_code{$leaf}{"code"};
				} else {
					$code_control{$leaf_code{$leaf}{"rank"}}{"number"} += 1;
					$code_control{$leaf_code{$leaf}{"rank"}}{"code"}{$leaf_code{$leaf}{"code"}}{"number"} = $code_control{$leaf_code{$leaf}{"rank"}}{"number"};
					$code_control{$leaf_code{$leaf}{"rank"}}{"count"}{$leaf_code{$leaf}{"code"}} = 1;
					$code_control{$leaf_code{$leaf}{"rank"}}{"code"}{$leaf_code{$leaf}{"code"}}{"lca"} = $leaf_code{$leaf}{"lca"};
					$code_control{$leaf_code{$leaf}{"rank"}}{"code"}{$leaf_code{$leaf}{"code"}}{"txid"} = $leaf_code{$leaf}{"txid"};
					$code_control{$leaf_code{$leaf}{"rank"}}{"code"}{$leaf_code{$leaf}{"code"}}{"query"} = $leaf_code{$leaf}{"query"};
					$code_control{$leaf_code{$leaf}{"rank"}}{"code"}{$leaf_code{$leaf}{"code"}}{"queryTax"} = $leaf_code{$leaf}{"queryTax"};
					$code_control{$leaf_code{$leaf}{"rank"}}{"code"}{$leaf_code{$leaf}{"code"}}{"boot"} = $leaf_code{$leaf}{"boot"};
					$code_control{$leaf_code{$leaf}{"rank"}}{"code"}{$leaf_code{$leaf}{"code"}}{"meanDistance"} = $leaf_code{$leaf}{"meanDistance"};
					$code_control{$leaf_code{$leaf}{"rank"}}{"code"}{$leaf_code{$leaf}{"code"}}{"neighbor"} = $codes2analyse{$leaf_code{$leaf}{"code"}}{"neighbor"};
					$code_control{$leaf_code{$leaf}{"rank"}}{"code"}{$leaf_code{$leaf}{"code"}}{"ancestor"} = $codes2analyse{$leaf_code{$leaf}{"code"}}{"ancestor"};
					$code_control{$leaf_code{$leaf}{"rank"}}{"code"}{$leaf_code{$leaf}{"code"}}{"dupNode"} = $leaf_code{$leaf}{"dupNode"};
					$leaf_rank{$leaf}{$q} = $leaf_code{$leaf}{"code"};
					if (exists $leaf_rank{$leaf}{$q - 1}){
						$code_control{$leaf_code{$leaf}{"rank"}}{"code"}{$leaf_code{$leaf}{"code"}}{"prevLevel"} = $leaf_rank{$leaf}{$q - 1};
					} else {
						$code_control{$leaf_code{$leaf}{"rank"}}{"code"}{$leaf_code{$leaf}{"code"}}{"prevLevel"} = "-";
					}
				}
			} else {
				$code_control{$leaf_code{$leaf}{"rank"}}{"number"} = 1;
				$code_control{$leaf_code{$leaf}{"rank"}}{"code"}{$leaf_code{$leaf}{"code"}}{"number"} = $code_control{$leaf_code{$leaf}{"rank"}}{"number"};
				$code_control{$leaf_code{$leaf}{"rank"}}{"count"}{$leaf_code{$leaf}{"code"}} = 1;
				$code_control{$leaf_code{$leaf}{"rank"}}{"code"}{$leaf_code{$leaf}{"code"}}{"lca"} = $leaf_code{$leaf}{"lca"};
				$code_control{$leaf_code{$leaf}{"rank"}}{"code"}{$leaf_code{$leaf}{"code"}}{"txid"} = $leaf_code{$leaf}{"txid"};
				$code_control{$leaf_code{$leaf}{"rank"}}{"code"}{$leaf_code{$leaf}{"code"}}{"query"} = $leaf_code{$leaf}{"query"};
				$code_control{$leaf_code{$leaf}{"rank"}}{"code"}{$leaf_code{$leaf}{"code"}}{"queryTax"} = $leaf_code{$leaf}{"queryTax"};
				$code_control{$leaf_code{$leaf}{"rank"}}{"code"}{$leaf_code{$leaf}{"code"}}{"boot"} = $leaf_code{$leaf}{"boot"};
				$code_control{$leaf_code{$leaf}{"rank"}}{"code"}{$leaf_code{$leaf}{"code"}}{"meanDistance"} = $leaf_code{$leaf}{"meanDistance"};
				$code_control{$leaf_code{$leaf}{"rank"}}{"code"}{$leaf_code{$leaf}{"code"}}{"neighbor"} = $codes2analyse{$leaf_code{$leaf}{"code"}}{"neighbor"};
				$code_control{$leaf_code{$leaf}{"rank"}}{"code"}{$leaf_code{$leaf}{"code"}}{"ancestor"} = $codes2analyse{$leaf_code{$leaf}{"code"}}{"ancestor"};
				$code_control{$leaf_code{$leaf}{"rank"}}{"code"}{$leaf_code{$leaf}{"code"}}{"dupNode"} = $leaf_code{$leaf}{"dupNode"};
				$leaf_rank{$leaf}{$q} = $leaf_code{$leaf}{"code"};
				if (exists $leaf_rank{$leaf}{$q - 1}){
					$code_control{$leaf_code{$leaf}{"rank"}}{"code"}{$leaf_code{$leaf}{"code"}}{"prevLevel"} = $leaf_rank{$leaf}{$q - 1};
				} else {
					$code_control{$leaf_code{$leaf}{"rank"}}{"code"}{$leaf_code{$leaf}{"code"}}{"prevLevel"} = "-";
				}
			}
		}
		print TABLE "Taxonomy rank: ".$taxSimple_ranks_map[$i - 1]."\n";
		#print TABLE "clusterid\ttaxon\tcluster\tprevCluster\tcount\tlca\tdistinctSp\tquery\tqueryOrg\tboot\tmeanDistance\tsisterGrp\toutGrp\n";
		print TABLE "clusterid\ttaxon\tprevCluster\tbranch\tcount\tlca\tdistinctSp\tquery\tqueryOrg\tboot\tmeanDistance\tsisterGrp\toutGrp\n";
		my @printArray;
		foreach my $rank1 (sort keys %code_control){
			foreach my $code1 (sort keys %{$code_control{$rank1}{"code"}}){
				my @arrayRank = (	$rank1, 
									$code_control{$rank1}{"code"}{$code1}{"number"}, 
									$code_control{$rank1}{"count"}{$code1}, 
									$code_control{$rank1}{"code"}{$code1}{"lca"}, 
									$code_control{$rank1}{"code"}{$code1}{"txid"}, 
									$code_control{$rank1}{"code"}{$code1}{"query"}, 
									$code_control{$rank1}{"code"}{$code1}{"boot"}, 
									sprintf("%.4f", $code_control{$rank1}{"code"}{$code1}{"meanDistance"}), 
									$code_control{$rank1}{"code"}{$code1}{"neighbor"}, 
									$code_control{$rank1}{"code"}{$code1}{"ancestor"}, 
									$code1, 
									$code_control{$rank1}{"code"}{$code1}{"prevLevel"}, 
									$code_control{$rank1}{"code"}{$code1}{"queryTax"}, 
									$code_control{$rank1}{"code"}{$code1}{"dupNode"}
								);
				push (@printArray, [@arrayRank]);
				#print TABLE $rank1."\t".$code_control{$rank1}{"code"}{$code1}."\t".$code_control{$rank1}{"count"}{$code1}."\t".$code_control{$rank1}{"lca"}."\n";
			}
		}
		@printArray = sort { $a->[1] <=> $b->[1] } @printArray;
		@printArray = sort { $a->[0] cmp $b->[0] } @printArray;
		@printArray = sort { $b->[3] <=> $a->[3] } @printArray;
		@printArray = sort { $a->[7] <=> $b->[7] } @printArray;
		#@printArray = sort { $a->[11] cmp $b->[11] } @printArray;
		my %code;
		my %code_number;
		#my $max_dupNode_number = 0;
		my %code_dupNode;
		for(my $k = 0; $k < scalar @printArray; $k++){			
			#$code{$printArray[$k][10]} = $k+1;
			my $zeroLenght = length(scalar keys %{$taxSimple_code{"rank"}{$taxSimple_ranks_map[$i-1]}});
			my $code2 = sprintf("%0${zeroLenght}d",$taxSimple_code{"rank"}{$taxSimple_ranks_map[$i-1]}{$printArray[$k][0]});
			$zeroLenght = length($code_control{$printArray[$k][0]}{"number"});
			$code_number{$printArray[$k][0]} += 1;
			my $code3 = sprintf("%0${zeroLenght}d",$code_number{$printArray[$k][0]});
			$code{$printArray[$k][10]} = $code2."_".$code3;
			
		}
		
		foreach my $leafid(keys %leaf_rank){
			$leaf_rank{$leafid}{$q} = $code{$leaf_rank{$leafid}{$q}};
		}
		for(my $k = 0; $k < scalar @printArray; $k++){
			print TABLE $code{$printArray[$k][10]}."\t".$printArray[$k][0]."\t".$printArray[$k][11]."\t".$printArray[$k][13]."\t".$printArray[$k][2]."\tn".$printArray[$k][3]."\t".$printArray[$k][4]."\t".$printArray[$k][5]."\t".$printArray[$k][12]."\t".$printArray[$k][6]."\t".$printArray[$k][7]."\t";
			if ($printArray[$k][8] eq "-"){
				print TABLE "-\t";
			} else {
				my @codes = split(";", $printArray[$k][8]);
				foreach (my $j = 0; $j < scalar @codes; $j++){
					$codes[$j] = $code{$codes[$j]};
				}
				@codes = sort { $a cmp $b} @codes;
				print TABLE join(";", @codes)."\t";
			}
			if ($printArray[$k][9] eq "-"){
				print TABLE "-\t";
			} else {
				my @codes = split(";", $printArray[$k][9]);
				foreach (my $j = 0; $j < scalar @codes; $j++){
					$codes[$j] = $code{$codes[$j]};
				}
				@codes = sort { $a cmp $b} @codes;
				print TABLE join(";", @codes)."\t";
			}
			print TABLE "\n";
		}
		print TABLE "\n";
	}

	close TABLE;
	
	####
	
	
	# Rename tree leaves
	# id
	# accession
	# geneID
	# geneName
	# header
	# species
	# lca
	# lcaN
	# rankname
	# rankcode
	# Default: lcaN id geneName rankcode(family,order,class)
	#my @leafNameOption = ("lcaN","id","geneName","rankcode(family,order,class)");
	@leaves = $treeTag -> get_leaf_nodes();
	
	my $searchQuery = quotemeta $queryInfo{"name"};
	
	my %hash_leafName; # grant uniq leaf name on the tree.
	
	foreach my $leaf(@leaves){
		my $leafid = $leaf -> id();
		my $leafTxid = $hashCode{"code"}{$leafid}{"txid"};
		my $leafid2 = $hashCode{"code"}{$leafid}{"id"};
		my %leafName;
		$leafName{"lcan"} = "(n".$map_txid{"pair2pairLCA"}{$leafTxid}{"lcaN"}{$txidMap}.")";
		$leafName{"lca"} = $map_txid{"pair2pairLCA"}{$leafTxid}{"lca"}{$txidMap};
		$leafName{"id"} = $generalInfo{$leafid2}{"id"};
		$leafName{"accession"} = $generalInfo{$leafid2}{"accession"};
		$leafName{"species"} = $map_txid{"txids"}{$leafTxid}{"name"};
		$leafName{"geneid"} = $generalInfo{$leafid2}{"geneID"};
		if ($generalInfo{$leafid2}{"geneName"}){
			$leafName{"genename"} = $generalInfo{$leafid2}{"geneName"};
			$leafName{"genename"} =~ s/,$//;
		} else {
			$leafName{"genename"} = "NULL";
		}
		
		#$leafName{"header"} = $generalInfo{$leafid}{"fastaHeader"};
		
		if (exists $leafNameOptions{"rankcode"}){
			my @joinRank;
			my @selectedRanks = @{$leafNameOptions{"rankcode"}};
			foreach my $keyRank (@selectedRanks){
				push (@joinRank, $taxSimple_code{"leaf"}{$leafid}{$keyRank});
			}
			$leafName{"rankcode"} = '('.join(",", @joinRank).')';
		}
		if (exists $leafNameOptions{"rankname"}){
			my @joinRank;
			my @selectedRanks = @{$leafNameOptions{"rankname"}};
			foreach my $keyRank (@selectedRanks){
				my @keys = grep { $taxSimple_code{"rank"}{$keyRank}{$_} eq $taxSimple_code{"leaf"}{$leafid}{$keyRank} } keys %{$taxSimple_code{"rank"}{$keyRank}};
				push (@joinRank, $keys[0]);
			}
			$leafName{"rankname"} = '('.join(",", @joinRank).')';
		}
		$leafName{"name"} .= '"';
		foreach my $type(@leafNameOptions){
			$leafName{"name"} .= $leafName{$type}." ";
		}
		chop $leafName{"name"};
		
		if (exists $hash_leafName{$leafName{"name"}}){
			$hash_leafName{$leafName{"name"}} += 1;
			$leafName{"name"} .= " (".$hash_leafName{$leafName{"name"}}.")";
		} else {
			$hash_leafName{$leafName{"name"}} = 1;
		}
		$leafName{"name"} .= '"';
		
		if (($leafid eq "ID1")){
			$queryInfo{"leaf"} = $leafName{"name"};
		} 
		$leaf -> id($leafName{"name"});
		
	}
	
	return ($treeTag);

}
	
sub treeConvertNexus {
	
	# convert NHX to Nexus;
	my ($refLeaves) = @_;
	open(TREE, "< ".$pid."_seq_tree.nhx") or die;
	open(TREEOUT, "> ".$pid."_seq_tree.nex") or die;
	
	my @leaves = @$refLeaves;
	print TREEOUT 
"#NEXUS
[File generated by $TaxOnTreeVersion]
Begin taxa;
	Dimensions ntax=".scalar @leaves.";
	Taxlabels\n";
	my $searchQuery = quotemeta $queryInfo{"leaf"};
	foreach my $leaf(@leaves){
	
		my $leafid = $leaf -> id();
		if ($queryInfo{"name"}){
			
			if ($leafid =~ m/$searchQuery/){
				print TREEOUT "\t\t".$leafid."[&!color=#-52429]\n";
			} else {
				print TREEOUT "\t\t".$leafid."\n";
			}
		} else {
			print TREEOUT "\t\t".$leafid."\n";
		}
		
	}
	print TREEOUT "\t\t;\nend;\n\n";
	
	my $tree = <TREE>;
	my $tree2 = $tree;
	my $definiteTree = '';
	while(index($tree, "[&") != -1){
		$definiteTree .= substr($tree, 0, index($tree, "[&"));
		my $restTree = substr($tree, index($tree, "[&"));
		my $left = 0;
		my $right = 1;
		my $offset = 0;
		my $nextOffset = 0;
		my $tag;
		while ($left != $right){
			$offset = $nextOffset;
			$tag = substr($restTree, index($restTree, "[&"), index($restTree, "]", $offset) - index($restTree, "[&") + 1);
			my @leftMatches = ($tag =~ /\[/g);
			my @rightMatches = ($tag =~ /\]/g);
			$left = @leftMatches;
			$right = @rightMatches;
			$nextOffset = index($restTree, "]", $offset) + 1;
		}
		$tag =~ s/&&NHX:/&/g;
		$tag =~ s/:/,/g;
		$definiteTree .= $tag;
		$tree = substr($restTree, index($restTree, "]", $offset)+ 1);
	}
	$definiteTree .= $tree;
	$definiteTree =~ s/\[&&NHX\]//g;
	
	my $color_legend;
	my @rankOrder;
	my $n = -1;
	my @rank_query = @{$map_txid{"txids"}{$txidMap}{"rank"}};
	foreach my $lineage(@{$map_txid{"txids"}{$txidMap}{"lineageName"}}){
		$n++;
		next if ($n < $map_txid{"minLCA"});
		my $legend = "(n".$n.") ".$lineage." / ".$rank_query[$n];
		my $searchLegend = quotemeta $legend;
		$legend .= "*" if (!($tree2 =~ m/$searchLegend/));
		unshift (@rankOrder, $legend);
	}
	for(my $l = $#rankOrder; $l >=0; $l--){
		if ($rankOrder[$l] =~ /\*$/){
			pop(@rankOrder);
		} else {
			last;
		}
	}
	$color_legend = join(",", @rankOrder);
	print TREEOUT "Begin trees;\n\n";
	print TREEOUT "tree TREE1 = $definiteTree\nend;\n\n";
	print TREEOUT 'Begin figtree;
	set appearance.backgroundColorAttribute="Default";
	set appearance.backgroundColour=#-1;
	set appearance.branchColorAttribute="lca";
	set appearance.branchLineWidth=3.0;
	set appearance.branchMinLineWidth=0.0;
	set appearance.branchWidthAttribute="Fixed";
	set appearance.foregroundColour=#-16777216;
	set appearance.selectionColour=#-2144520576;
	set branchLabels.colorAttribute="User selection";
	set branchLabels.displayAttribute="Branch times";
	set branchLabels.fontName="Arial";
	set branchLabels.fontSize=8;
	set branchLabels.fontStyle=0;
	set branchLabels.isShown=false;
	set branchLabels.significantDigits=4;
	set colour.order.lca="lca:'.$color_legend.'";
	set colour.scheme.lca="lca:HSBDiscrete{hue,1,0.0,0.9,0.6,0.6,0.4,0.8}";
	set layout.expansion=276;
	set layout.layoutType="RECTILINEAR";
	set layout.zoom=0;
	set legend.attribute="lca";
	set legend.fontSize=12.0;
	set legend.isShown=true;
	set legend.significantDigits=4;
	set nodeBars.barWidth=4.0;
	set nodeBars.displayAttribute=null;
	set nodeBars.isShown=false;
	set nodeLabels.colorAttribute="User selection";
	set nodeLabels.displayAttribute="BOOT";
	set nodeLabels.fontName="Arial";
	set nodeLabels.fontSize=8;
	set nodeLabels.fontStyle=0;
	set nodeLabels.isShown=false;
	set nodeLabels.significantDigits=4;
	set nodeShape.colourAttribute=null;
	set nodeShape.isShown=true;
	set nodeShape.minSize=1.0;
	set nodeShape.scaleType=Width;
	set nodeShape.shapeType=Circle;
	set nodeShape.size=6.0;
	set nodeShape.sizeAttribute="BOOT";
	set nodeShapeExternal.colourAttribute="User selection";
	set nodeShapeExternal.isShown=false;
	set nodeShapeExternal.minSize=10.0;
	set nodeShapeExternal.scaleType=Width;
	set nodeShapeExternal.shapeType=Circle;
	set nodeShapeExternal.size=4.0;
	set nodeShapeExternal.sizeAttribute="Fixed";
	set nodeShapeInternal.colourAttribute="User selection";
	set nodeShapeInternal.isShown=true;
	set nodeShapeInternal.minSize=0.0;
	set nodeShapeInternal.scaleType=Width;
	set nodeShapeInternal.shapeType=Circle;
	set nodeShapeInternal.size=8.0;
	set nodeShapeInternal.sizeAttribute="BOOT";
	set polarLayout.alignTipLabels=false;
	set polarLayout.angularRange=0;
	set polarLayout.rootAngle=0;
	set polarLayout.rootLength=100;
	set polarLayout.showRoot=true;
	set radialLayout.spread=0.0;
	set rectilinearLayout.alignTipLabels=false;
	set rectilinearLayout.curvature=0;
	set rectilinearLayout.rootLength=100;
	set scale.offsetAge=0.0;
	set scale.rootAge=1.0;
	set scale.scaleFactor=1.0;
	set scale.scaleRoot=false;
	set scaleAxis.automaticScale=true;
	set scaleAxis.fontSize=8.0;
	set scaleAxis.isShown=false;
	set scaleAxis.lineWidth=1.0;
	set scaleAxis.majorTicks=1.0;
	set scaleAxis.origin=0.0;
	set scaleAxis.reverseAxis=false;
	set scaleAxis.showGrid=true;
	set scaleBar.automaticScale=true;
	set scaleBar.fontSize=10.0;
	set scaleBar.isShown=true;
	set scaleBar.lineWidth=1.0;
	set scaleBar.scaleRange=0.0;
	set tipLabels.colorAttribute="User selection";
	set tipLabels.displayAttribute="Names";
	set tipLabels.fontName="Arial";
	set tipLabels.fontSize=10;
	set tipLabels.fontStyle=0;
	set tipLabels.isShown=true;
	set tipLabels.significantDigits=4;
	set trees.order=true;
	set trees.orderType="increasing";
	set trees.rooting=false;
	set trees.rootingType="User Selection";
	set trees.transform=false;
	set trees.transformType="cladogram";
end;';
	
	close TREE;
	system("rm ".$pid."_seq_tree.nhx");
}

1;
