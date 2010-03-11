#!/usr/bin/perl

use strict;
use Encode::HanConvert;
use Getopt::Long;
use MP3::Tag;

binmode STDOUT, ":utf8"; 

my ($do_confirm, $noconfirm, $s2t, $t2s, $b2t, $g2t, $debug);

GetOptions(
    "noconfirm" => \$noconfirm,
    "s2t"       => \$s2t,
    "t2s"       => \$t2s,
    "b2t"       => \$b2t,
    "g2t"       => \$g2t,
    "debug"     => \$debug,
);

usage() unless ($ARGV[0]);

$do_confirm = ($noconfirm) ? 0 : 1;
if    ($t2s) { *convert = \&trad_to_simp; }
elsif ($g2t) { *convert = \&gb_to_trad;   }
elsif ($b2t) { *convert = \&big5_to_trad; }
elsif ($s2t) { *convert = \&simp_to_trad; }
else         { *convert = \&simp_to_trad; }

sub usage
{
    my ($script) = ($0 =~ /([^\/]+)$/);
    my $usage = <<EOF;
Usage: $script [--noconfirm] [--s2t] [--t2s] [--g2t] [--b2t] file1 [file2] ... [fileN]

    --noconfirm - skip confirmation
    --s2t       - convert Unicode Simplified to Unicode Traditional [Default]
    --t2s       - convert Unicode Traditional to Unicode Simplified
    --g2t       - convert GB to Unicode Traditional
    --b2t       - convert Big5 to Unicode Traditional

EOF
    print STDERR $usage;
    exit 1;
}

sub debug
{
    print STDERR shift if $debug;
}

sub error
{
    print STDERR shift;
    exit 2;
}

sub process_file
{
    my ($file) = @_;
    my ($mp3, $id3v2, @converted_frame_ids);
    my (%old, %new);

    error "process_file: $file is a directory.\n" if (-d $file);
    error "process_file: $file doesn't exist.\n" unless (-f $file);

    $mp3 = MP3::Tag->new($file);

    # hashref of tag values (e.g. { title => 'Kids', artist => 'MGMT', ... })
    my $values = $mp3->autoinfo();

    # generated hashref of tag values
    my $converted_values = { map { $_ => convert($values->{$_}) } keys(%{$values}) }; 

    foreach my $field qw(title artist album comment)
    {
        if ($values->{$field})
        {
            printf "%s: [%s] => [%s]\n", $field, $values->{$field}, $converted_values->{$field};
        }
    }

    my $do_convert = 1;
    if ($do_confirm)
    {
        print "Convert? [y/N] ";
        my $reply = <STDIN>;
        chomp($reply);
        $do_convert = (uc($reply) eq 'Y') ? 1 : 0;
    }

    $mp3->update_tags($converted_values, 1) if ($do_convert);

    $mp3->close();
}

sub main
{
    foreach my $file (@ARGV)
    {
        eval
        {
            debug "calling process_file\n";
            process_file($file);
            debug "done process_file\n";
        };
        if ($@)
        {
            print STDERR "error: $@\n";
            next;
        }
    }
}

main();
exit 0;
