#!/usr/bin/perl

use strict;
use Encode::HanConvert;
use Getopt::Long;
use MP3::Tag;

binmode STDOUT, ":utf8"; 

my ($do_confirm, $noconfirm, $s2t, $t2s, $b2t, $g2t);
my @frame_ids = qw(TIT2 TPE1 TPE2 TALB TCON COMM USLT); # title artist album_artist album genre comment lyrics

GetOptions(
    "noconfirm" => \$noconfirm,
    "s2t"       => \$s2t,
    "t2s"       => \$t2s,
    "b2t"       => \$b2t,
    "g2t"       => \$g2t,
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

sub trim
{
    my ($str, $maxlen) = @_;
    $maxlen ||= 40;
    return (length($str) > $maxlen) ? substr($str, 0, $maxlen) . '...' : $str;
}

sub strip_cr
{
    my $str = shift;
    $str =~ s/\r//g;
    $str =~ s/\n/ /g;
    return $str;
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
    $mp3->get_tags;
    $id3v2 = $mp3->{ID3v2};

    next unless $id3v2;

    foreach my $frame_id (@frame_ids)
    {
        my ($frame_value, $frame_name) = $id3v2->get_frame($frame_id);

        next unless $frame_value;

        if (ref $frame_value)
        {
            ## only process comments and lyrics
            next unless ($frame_id eq 'COMM' || $frame_id eq 'USLT');

            ## skip special comments like iTunNORM
            next if ($frame_value->{Description});

            ## fetch the frame with the given $frame_id based on the given language priority
            my $frame_select_value = $id3v2->frame_select($frame_id, '', ['chi', 'eng', '']);

            $old{$frame_id} = $frame_select_value;
            $new{$frame_id} = convert($frame_select_value);
            printf "$frame_name ($frame_id): [%s] => [%s]\n", trim(strip_cr($old{$frame_id})), trim(strip_cr($new{$frame_id}));
            my $new_lang = ($frame_id eq 'COMM') ? 'eng' : $frame_value->{Language};  # iTunes workaround

            ## removed other found frames and add/replace existing frame using $new_lang
            my $frames_affected = $id3v2->frame_select($frame_id, '', [$new_lang, 'chi', 'eng', ''], $new{$frame_id});
            print "frames_affected=$frames_affected\n";
        }
        else
        {
            $old{$frame_id} = $frame_value;
            $new{$frame_id} = convert($frame_value);

            printf "$frame_name ($frame_id):\n  [%s] => [%s]\n", $old{$frame_id}, $new{$frame_id};

            $id3v2->change_frame($frame_id, $new{$frame_id});
        }

        push(@converted_frame_ids, $frame_id);
    }

    my $do_convert = 1;
    if ($do_confirm)
    {
        print "Convert? [y/N] ";
        my $reply = <STDIN>;
        chomp($reply);
        $do_convert = (uc($reply) eq 'Y') ? 1 : 0;
    }

    $id3v2->write_tag() if ($do_convert);

    $mp3->close();
}

sub main
{
    foreach my $file (@ARGV)
    {
        eval
        {
            #print "calling process_file\n";
            process_file($file);
        };
        if ($@)
        {
            print "error: $@\n";
            next;
        }
    }
}

main();
exit 0;
