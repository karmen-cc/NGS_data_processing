package mathSunhh; 
#BEGIN {
#	push(@INC,'/usr/local/share/perl5/'); 
#}
# This is a package storing sub functions. 
# So there isn't objects created. 
use strict; 
use warnings; 
use Statistics::Descriptive; 
use Exporter qw(import);
our @EXPORT = qw(ins_calc ovl_len);
our @EXPORT_OK = qw();


sub ovl_len {
	my ($s1, $e1, $s2, $e2) = @_; 
	($s1, $e1) = sort {$a <=> $b} ($s1, $e1); 
	($s2, $e2) = sort {$a <=> $b} ($s2, $e2); 
	if ($e1 < $s2 or $s1 > $e2) {
		return 0; 
	} else {
		return &min($e1, $e2) - &max($s1, $s2) + 1; 
	}
}

sub min {
	my $min = shift; 
	for (@_) {
		$min > $_ and $min = $_; 
	}
	return $min; 
}
sub max {
	my $max = shift; 
	for (@_) {
		$max < $_ and $max = $_; 
	}
	return $max; 
}

# Function: ins_avg ()
# Description: For calculating insert sizes. 
#              Following Heng Li's bwa method (Estimating Insert Size Distribution). 
#              But the max/min distance of INS are only using 6 * sigma values. 
#              http://linux.die.net/man/1/bwa
#              BWA estimates the insert size distribution per 256*1024 read pairs. It first collects pairs of reads with both ends mapped with a single-end quality 20 or higher and then calculates median (Q2), lower and higher quartile (Q1 and Q3). It estimates the mean and the variance of the insert size distribution from pairs whose insert sizes are within interval [Q1-2(Q3-Q1), Q3+2(Q3-Q1)]. The maximum distance x for a pair considered to be properly paired (SAM flag 0x2) is calculated by solving equation Phi((x-mu)/sigma)=x/L*p0, where mu is the mean, sigma is the standard error of the insert size distribution, L is the length of the genome, p0 is prior of anomalous pair and Phi() is the standard cumulative distribution function. For mapping Illumina short-insert reads to the human genome, x is about 6-7 sigma away from the mean. Quartiles, mean, variance and x will be printed to the standard error output.
# Input      : (\@ins_value_array)
# Output     : (\%hash_of_values) 
#              keys = qw(Q1 Q3 interval_low interval_high interval_mean interval_median interval_var interval_stdev limit_low limit_high)
sub ins_calc {
	my $r_arr = shift; 
	my $min_val_number = shift // 1; 
	my %back; 
	if (scalar(@$r_arr) < $min_val_number) {
		for my $ta (qw/Q1 Q3 interval_low interval_high interval_mean interval_median interval_var interval_stdev limit_low limit_high/) {
			$back{$ta} = ''; 
		}
		return \%back; 
	}
	my $stat = Statistics::Descriptive::Full->new();
	$stat->add_data(@$r_arr); 
	$back{'Q1'} = $stat->quantile(1); 
	$back{'Q3'} = $stat->quantile(3); 
	$back{'interval_low'}  = $back{'Q1'} - 2 * ($back{'Q3'}-$back{'Q1'}); 
	$back{'interval_high'} = $back{'Q3'} + 2 * ($back{'Q3'}-$back{'Q1'}); 
	
	$stat->clear(); 
	my @sub_arr; 
	for my $ta (@$r_arr) {
		$ta >= $back{'interval_low'} and $ta <= $back{'interval_high'} and push(@sub_arr, $ta); 
	}
	$stat->add_data(@sub_arr); 
	$back{'interval_mean'}  = $stat->mean(); 
	$back{'interval_median'} = $stat->median(); 
	$back{'interval_var'}   = $stat->variance(); 
	$back{'interval_stdev'} = $stat->standard_deviation(); 
	$back{'limit_low'}  = $back{'interval_mean'} - 6 * $back{'interval_stdev'}; 
	$back{'limit_high'} = $back{'interval_mean'} + 6 * $back{'interval_stdev'}; 
	$stat->clear(); 
	return \%back; 
}

# Given (\@list_of_ele, $n_in_class), return all permutations by array. Return ([@perm1_of_ele], [@perm2], ...)
sub permutations {
	my ($list, $n) = @_; 
	$n = $n // scalar(@$list); 
	$n > @$list and return ($list); 
	$n <= 1 and return(map {[$_]} @$list); 
	my @perm; 
	for my $i (0 .. $#$list) {
		my @rest = @$list; 
		my $val = splice(@rest, $i, 1); 
		for ( &permutations(\@rest, $n-1) ) {
			push(@perm, [$val, @$_]); 
		}
	}
	return @perm; 
}#sub permutations() 

# Given (\@list_of_ele, $n_in_class), return all combinations by array. Return ([@comb1_of_ele], [@comb2_of_ele], ...) 
sub combinations {
	my ($list, $n) = @_; 
	$n = $n // scalar(@$list); 
	$n > @$list and return ($list); 
	$n <= 1 and return(map {[$_]} @$list); 
	my @comb; 
	for (my $i=0; $i+$n<=@$list; $i++) {
		my $val = $list->[$i]; 
		my @rest = @$list[$i+1 .. $#$list]; 
		for (&combinations(\@rest, $n-1)) {
			push(@comb, [$val, @$_]); 
		}
	}
	return @comb; 
}#sub combinations



1; 
