#!/usr/bin/perl
use strict; 
use warnings; 
use LogInforSunhh; 

!@ARGV and &stopErr("perl $0 in.rmFP.full.fa\n"); 

my $min_ident = 80; 
my $min_cov = 90; 


my $faF = 'PG1All_v2.scf.fa.gff99.dgt.slct.infor.name.filtN.filtFlank.rmFP.full.fa'; 
$faF = shift; 
my $outFaF = "$faF.examplars"; 
open FA,'<',"$faF" or die; 
my (@in_seq, @in_id); 
my %toIncl; 
while (<FA>) {
	if (m/^>(\S+)/) {
		my $tkey = $1; 
		$toIncl{$tkey} = 1; 
		push(@in_id, $tkey); 
		push(@in_seq, ''); 
	}else{
		$in_seq[-1] .= $_; 
	}
}
close FA; 
my %id2seq; 
for (my $i=0; $i<@in_seq; $i++) {
	$in_seq[$i] =~ s/\s//g; 
	defined $id2seq{$in_id[$i]} and die "repeat id: $in_id[$i]\n"; 
	$id2seq{$in_id[$i]} = $in_seq[$i]; 
}

# 
my %toExcl; 
my $round = 0; 
open OO,'>',"$outFaF" or die; 
while ( my $prev_num = scalar(keys %toIncl) ) {
	$round ++; 
	my $fa_name = "tmp.fa"; 
	my $bn6_name = "tmp.fa.bn6"; 
	&exeCmd("rm -f $fa_name $bn6_name"); 
	&run_blastn( \@in_id, \@in_seq, \%toIncl, $fa_name, $bn6_name ); 
	my ( $bestID, $bestID_matN, $toRMR ) = &get_examplar( $bn6_name, { "min_ident"=>$min_ident, "min_cov"=>$min_cov } ); 
	for (keys %{$toRMR}) {
		delete $toIncl{$_}; 
	}
	defined $toIncl{$bestID} and die "? $bestID not excluded.\n"; 
	my $curr_num = scalar(keys %toIncl); 
	&tsmsg("[Msg] round-$round keep $bestID . Rest $curr_num from $prev_num\n"); 
	print OO ">$bestID\n$id2seq{$bestID}\n"; 
	if ( $bestID_matN == 1 ) {
		&tsmsg("[Msg] No multiple matches now. Output all rest sequences.\n"); 
		for ( my $i=0; $i<@in_id; $i++ ) {
			defined $toIncl{ $in_id[$i] } or next; 
			delete $toIncl{ $in_id[$i] } ; 
			print OO ">$in_id[$i]\n$in_seq[$i]\n"; 
		}
	}
}
close OO; 

sub run_blastn {
	my ($in_idR, $in_seqR, $in_inclR, $fa_name, $bn6_name) = @_; 
	scalar(@$in_idR) == scalar(@$in_seqR) or die "not equal\n"; 
	open O,'>',"$fa_name" or die; 
	for (my $i=0; $i<@$in_idR; $i++) {
		defined $in_inclR->{ $in_idR->[$i] } or next; 
		print O ">$in_idR->[$i]\n$in_seqR->[$i]\n"; 
	}
	close O; 
	&exeCmd("makeblastdb -in $fa_name -dbtype nucl"); 
	&exeCmd("blastn -num_threads 20 -task blastn -dust no -outfmt \"6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore qlen slen sstrand\" -query $fa_name -db $fa_name -out ${fa_name}.bn6 -max_target_seqs 9999"); 
	return 0; 
}

sub get_examplar {
	my ($bn6, $paraR) = @_; 
	if (!defined $paraR) {
		$paraR->{min_ident} = 80; 
		$paraR->{min_cov} = 90; 
	}
	defined $paraR->{min_ident} or $paraR->{min_ident} = 80;
	defined $paraR->{min_cov} or $paraR->{min_cov} = 90; 
	open BN6,'<',"$bn6" or die; 
	my %blocks; 
	my (%len1, %len2); 
	while (<BN6>) {
		chomp; 
		my @ta = split(/\t/, $_); 
		$ta[2] >= $paraR->{min_ident} or next; 
		my ($ss,$se) = sort {$a<=>$b} @ta[8,9]; 
		defined $len1{$ta[0]} or $len1{$ta[0]} = $ta[12]; 
		defined $len2{$ta[1]} or $len2{$ta[1]} = $ta[13]; 
		push(@{$blocks{$ta[0]}{$ta[1]}}, [ $ss, $se ]); 
	}
	close BN6; 
	# Merge blocks. 
	my %cnt; 
	for my $q_id (sort keys %blocks) {
		for my $s_id (sort keys %{$blocks{$q_id}}) {
			my @sub_blk; 
			for my $t1 ( sort { $a->[0] <=> $b->[0] || $a->[1] <=> $b->[1] } @{$blocks{$q_id}{$s_id}} ) {
				if ( scalar(@sub_blk) == 0 ) {
					push(@sub_blk, [$t1->[0], $t1->[1]]); 
				}else{
					if ( $sub_blk[-1][1] >= $t1->[0] ) {
						$t1->[1] > $sub_blk[-1][1] and $sub_blk[-1][1] = $t1->[1]; 
					} else {
						push(@sub_blk, [$t1->[0], $t1->[1]]); 
					}
				}
			}
			my $sum=0; 
			for my $t2 (@sub_blk) {
				$sum += ($t2->[1]-$t2->[0]+1); 
			}
			$sum >= $paraR->{min_cov}/100 * $len2{$s_id} or next; 
			$cnt{$q_id}{num} ++; 
			$cnt{$q_id}{score} += $sum; 
			$cnt{$q_id}{mat}{$s_id} = 1; 
		}
	}

	my @id_sort = sort { $cnt{$b}{num} <=> $cnt{$a}{num} || $cnt{$b}{score} <=> $cnt{$a}{score} } keys %cnt; 
	my $exm_id = $id_sort[0]; 
	my $exm_matN = $cnt{$exm_id}{num}; 
	my %toRM = %{ $cnt{$exm_id}{mat} }; 
	return ($exm_id, $exm_matN, \%toRM); 
}

# seq2_1873764_1876769_S400001_pilon	seq2_1873764_1876769_S400001_pilon	100.00	3006	0	0	1	3006	1	3006	0.0	 5422	3006	3006	plus
# seq2_1873764_1876769_S400001_pilon	seq2_1873764_1876769_S400001_pilon	99.81	518	1	0	2489	3006	1	518	0.0	  930	3006	3006	plus
