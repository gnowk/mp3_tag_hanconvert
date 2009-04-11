#!/usr/bin/perl

use strict;
use Encode::HanConvert;
use Getopt::Long;
use MP3::Tag;

my ($noconfirm, $s2t, $t2s, $b2t, $g2t);
GetOptions(
    "noconfirm" => \$noconfirm,
    "s2t"       => \$s2t,
    "t2s"       => \$t2s,
    "b2t"       => \$b2t,
    "g2t"       => \$g2t,
);

usage() unless ($ARGV[0]);

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
    die $usage;
}

if ($t2s) {
    *convert = \&trad_to_simp;
} elsif ($g2t) {
    *convert = \&gb_to_trad;
} elsif ($b2t) {
    *convert = \&big5_to_trad;
} else { ## s2t
    *convert = \&simp_to_trad;
}

binmode STDOUT, ":utf8";

my @tags = qw(artist album title track comment );
#my @tags = qw(comment );
my @v2_frames = qw(TIT2 TPE1 TPE2 TALB COMM USLT);
my $new_method = 1;

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

sub process_file
{
    my ($file) = @_;
    my (%old, %new);
    my ($mp3, $id3v2);

    $mp3 = MP3::Tag->new($file);
    $mp3->get_tags;

    %old = %{$mp3->autoinfo()};

    if ($new_method)
    {
        foreach my $tag (@tags)
        {
            $new{$tag} = convert($old{$tag});
            print "$tag: [$old{$tag}] => [$new{$tag}]\n";
        }
    }
    else
    {
        next unless (exists $mp3->{ID3v2});

        $id3v2 = $mp3->{ID3v2};

        my (%old, %new);
        foreach my $frame (@v2_frames)
        {
            my ($frame_value, $info) = $id3v2->get_frame($frame);
            $old{$frame} = $frame_value;
            $new{$frame} = convert($frame_value);

            print "$frame (old) => $old{$frame}\n";
            print "$frame (new) => $new{$frame}\n";
        }
    }

    my $do_convert = 'Y';
    if (!$noconfirm)
    {
        print "Convert? [y/N] ";
        $do_convert = <STDIN>;
        chomp($do_convert);
    }

    if (uc($do_convert) eq 'Y')
    {
        if ($new_method)
        {
            if (exists $mp3->{ID3v2})
            {
                $id3v2 = $mp3->{ID3v2};
                $id3v2->change_frame('TPE1', $new{artist});
                $id3v2->change_frame('TALB', $new{album});
                $id3v2->change_frame('TIT2', $new{title});
                $id3v2->change_frame('COMM', $new{comment});
                $id3v2->write_tag();
            }
            else
            {
                $mp3->new_tag('ID3v2');

                $mp3->{ID3v2}->add_frame('TPE1', $new{artist});
                $mp3->{ID3v2}->add_frame('TALB', $new{album});
                $mp3->{ID3v2}->add_frame('TIT2', $new{title});
                $mp3->{ID3v2}->add_frame('COMM', $new{comment});

                #$mp3->{ID3v2}->add_frame('TRCK', $old{track});
                #$mp3->{ID3v2}->add_frame('GNRE', $old{genre});
                #$mp3->{ID3v2}->add_frame('YEAR', $old{year});

                $mp3->{ID3v2}->write_tag;
            }
        }
        else
        {
            foreach my $frame (@v2_frames)
            {
                $id3v2->change_frame($frame, $new{$frame});
            }
            $id3v2->write_tag();
        }
    }

    $mp3->close();
}
