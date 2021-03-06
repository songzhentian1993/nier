package Nier::LicenseMatcher;

use strict;
#use warnings;
use File::Basename 'dirname';
use File::Spec::Functions 'catfile';
use Nier::LicenseRules;

sub new {
    my ($class, %args) = @_;

    my $self = bless({}, $class);

    die "parameter 'license_tokens' is mandatory" unless exists $args{license_tokens};

    my $path = dirname(__FILE__);

    $self->{verbose} = ($args{verbose} // 0) == 1;
    $self->{rules} = read_rules(catfile($path, 'rules.dict'));
    $self->{inter_rules} = read_inter_rules(catfile($path, 'interrules.dict'));

    my ($license_sentence_names, $originals) = read_license_tokens($args{license_tokens});
    $self->{license_sentence_names} = $license_sentence_names;
    $self->{originals} = $originals;

    $self->{count_matches} = 0;
    $self->{result} = [];

    return $self;
}

sub execute {
    my ($self) = @_;

    if (scalar(@{$self->{originals}}) == 0) {
        return 'NONE';
    }

    # matching spdx requires to match strict licenses, with no alternatives...

    my @license_sentence_names = @{$self->{license_sentence_names}};
    my $senttok = ',' . join(',', @license_sentence_names) . ',';
    print STDERR "senttok [$senttok]\n" if $self->{verbose};
    $senttok = $self->match_license($senttok);

    # do we have to check again?
    ## todo, verify that we have unmatched sentences...

    @license_sentence_names = split ',', $senttok;

    # first remove the extrict part from it
	#Perl evaluates any string to 0 if is not a number
    my $match = 0;
    for (my $i = 0; $i <= $#license_sentence_names; $i++) {
        if ($license_sentence_names[$i] == 0 &&
            $license_sentence_names[$i] ne 'UNKNOWN' &&
            $license_sentence_names[$i] ne '') {
            $license_sentence_names[$i] =~ s/Extrict$//;
            $match++;
        }
    }

    if ($match) {
        foreach my $inter_rule (@{$self->{inter_rules}}) {
            @license_sentence_names = map { $_ eq $inter_rule->[0] ? $inter_rule->[1] : $_ } @license_sentence_names;
        }

        $senttok = join(',', @license_sentence_names) . ',';
        print STDERR "senttok [$senttok]\n" if $self->{verbose};
        $senttok = $self->match_license($senttok);
    }

    return $self->generate_license_result($senttok);
}

sub is_unknown {
    my ($s) = @_;
    my @f = split /,/, $s;
    return $f[0] eq 'UNKNOWN';
}

sub read_rules {
    my ($file) = @_;
    my @rules = ();

    open my $fh, '<', $file or die "can't open file [$file]: $!";

    while (my $line = <$fh>) {
        chomp $line;
        # clean up spaces
        $line =~ s/^\s+//;
        $line =~ s/\s+$//;
        $line =~ s/\s*,\s*/,/g;
        $line =~ s/\s*:\s*/:/g;
        # check format
        if ($line =~ /^#/ || $line !~ /(.*):(.*,)*(.*)/) {
            next;
        }
        $line =~ /(.*?):(.*)/;
        push @rules, [$1, $2];
    }

    close $fh;

    return \@rules;
}

sub read_inter_rules {
    my ($file) = @_;
    my @inter_rules = ();

    open my $fh, '<', $file or die "can't open file [$file]: $!";

    while (my $line = <$fh>) {
        chomp $line;
        # check format
        if ($line =~ /^#/ || $line !~ /(.*?):(.*)/) {
            next;
        }
        foreach my $item (split /\|/, $2) {
            push @inter_rules, [$item, $1];
        }
    }

    close $fh;

    return \@inter_rules;
}

sub read_license_tokens {
    my ($license_tokens) = @_;

    my @tokens = ();
    my @originals = ();

    foreach my $license_token (@$license_tokens) {
        my @fields = split ':', $license_token;
        push @originals, $fields[1];
        my @token = split ';', $fields[0];
        push @tokens, $token[0];
    }

    return (\@tokens, \@originals);
}

# we will iterate over rules, matching as many as we can...
sub match_license {
    my ($self, $senttok) = @_;

    # create a string with the sentences
    foreach my $rule (@{$self->{rules}}) {
        my ($rule_name, $rule_tokens) = @$rule;
        my $rule_length = scalar(split ',', $rule_tokens);

        print STDERR "trying [$rule_name][$rule_tokens] on [$senttok]\n" if $self->{verbose};
        while ($senttok =~ s/,$rule_tokens,/,$rule_length,/) {
            print STDERR "rule matched\n" if $self->{verbose};
            $self->{count_matches}++;
            push @{$self->{result}}, $rule_name;
        }
    }

    # at this point we have removed all the matched sentences...
    print STDERR "senttok after matching rules [$senttok]\n" if $self->{verbose};
    print STDERR "result after matching rules [" . join(',', @{$self->{result}}) . "]\n" if $self->{verbose};

    if (scalar(@{$self->{result}}) > 0) {
        foreach my $rule (@Nier::LicenseRules::GENERAL_NON_CRITICAL) {
            while ($senttok =~ s/,$rule,/,-1,/) {
                ;
            }
        }
        print STDERR "senttok after removal of general non-critical rules [$senttok]\n" if $self->{verbose};

        foreach my $rule_name (@{$self->{result}}) {
            foreach my $rule (@{$Nier::LicenseRules::NON_CRITICAL_RULES{$rule_name}}) {
                while ($senttok =~ s/,$rule,/,-1,/g) {
                    ;
                }
            }
        }
        print STDERR "senttok after removal of non-critical rules [$senttok]\n" if $self->{verbose};
    }

    return $senttok;
}

sub generate_license_result {
    my ($self, $senttok) = @_;

    my @sections = split ',', $senttok;
    die 'assertion 1' if $sections[0] ne '';
    die 'assertion 2' if $sections[scalar(@sections)] ne '';

    my $ignored_lines = 0;
    my $license_lines = 0;
    my $unknown_lines = 0;
    my $unmatched_lines = 0;

    foreach my $i (1..scalar(@sections)-1) {
        if ($sections[$i] < 0) {
            $ignored_lines -= $sections[$i];
        } elsif ($sections[$i] != 0) {
            $license_lines += $sections[$i];
        } elsif ($sections[$i] eq 'UNKNOWN') {
            $unknown_lines++;
        } else {
            $unmatched_lines++;
        }
    }
    $senttok =~ s/^,(.*),$/$1/;

    my $license_result;
    if (scalar(@{$self->{result}}) == 0) {
        $license_result = 'UNKNOWN';
    } else {
        $license_result = join ',', @{$self->{result}};
    }
    # licenses; number of licenses matched;number of sentences matched; number of sentences ignored;number of sentences not matched;number of sentences unknown
    $license_result .= ";$self->{count_matches};$license_lines;$ignored_lines;$unmatched_lines;$unknown_lines;$senttok";

    return $license_result;
}

1;

__END__

