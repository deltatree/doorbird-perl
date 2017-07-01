#!/usr/bin/perl -w

use strict;
use LWP::UserAgent;
use HTTP::Request::Common;
use Time::HiRes;
use Time::Format qw(%time);

my $ua = LWP::UserAgent->new();

my $conf;
my $id;
my %device;

if ($#ARGV >= 1 && -e $ARGV[0])
{
        $conf = $ARGV[0];
        $id = $ARGV[1];
        %device = %{&initConf($conf)};

        if ($ARGV[2] =~ /--dumpPic/i && $#ARGV == 3)
        {
                &dumpPic(1,"manual");
        }
        elsif ($ARGV[2] =~ /--check/i)
        {
                my $request_string = 'http://'.${$device{$id}}{"hostname"}.'/bha-api/monitor.cgi?check=doorbell%2Cmotionsensor&';
                my $request = GET $request_string;
                $request->authorization_basic(${$device{$id}}{"user"},${$device{$id}}{"pass"});
                &log("Sending request: ".$request_string);

                my $response = $ua->request($request);

                if ($response->is_success) {
                        &log($response->decoded_content);
                }
                else {
                        die $request.": ".$response->status_line;
                }
        }
        elsif ($ARGV[2] =~ /--listenAndDumpPics/i && $#ARGV == 3)
        {
                my $request_string = 'http://'.${$device{$id}}{"hostname"}.'/bha-api/monitor.cgi?ring=doorbell%2Cmotionsensor&';
                my $request = GET $request_string;
                $request->authorization_basic(${$device{$id}}{"user"},${$device{$id}}{"pass"});
                &log("Sending request: ".$request_string);

                $ua->add_handler( "response_data" => \&dataHandler);

                my $response = $ua->request($request);

                if ($response->is_success) {
                        &log($response->decoded_content);
                }
                else {
                        die $request.": ".$response->status_line;
                }
        }
        elsif ($ARGV[2] =~ /--info/i)
        {
                my $request_string = 'http://'.${$device{$id}}{"hostname"}.'/bha-api/info.cgi';
                my $request = GET $request_string;
                $request->authorization_basic(${$device{$id}}{"user"},${$device{$id}}{"pass"});
                &log("Sending request: ".$request_string);
                my $response = $ua->request($request);

                if ($response->is_success) {
                        &log($response->decoded_content);
                }
                else {
                        die $request.": ".$response->status_line;
                }
        }
        else
        {
                &printUsage();
        }
}
else
{
        &printUsage();
}

#######################################
# Subroutinen
#######################################
sub printUsage()
{
        print "################################################\n";
        print "# \n";
        print "# Usage:\n";
        print "#   perl doorbird.pl {confFile} {deviceid} --info\n";
        print "#   perl doorbird.pl {confFile} {deviceid} --dumpPic {targetDirectory}\n";
        print "#   perl doorbird.pl {confFile} {deviceid} --check\n";
        print "#   perl doorbird.pl {confFile} {deviceid} --listenAndDumpPics {targetDirectory}\n";
        print "# \n";
        print "# \n";
        print "################################################\n";
        exit(1);
}

sub log()
{
        my $data = $_[0];
        chomp($data);
        $data =~ s/\r?\n\r?//g;
        print $time{'yyyymmdd-hh:mm:ss.mmm: '}.$data."\n";
}

sub dumpFile()
{
        my $target_dir = $_[0];
        my $target_hostname = $_[1];
        my $response = $_[2];
        my $filename = $time{'yyyy-mm-dd---hh-mm-ss-mmm'}."---".$target_hostname.".jpg";
        &log($filename);
        open(FILE,">".$target_dir.$filename);
        print FILE $response;
        close(FILE);
}

sub initConf()
{
        my $conf = $_[0];

        my %result;

        open(FILE,"<$conf");
        foreach my $line (<FILE>)
        {
                chomp($line);
                my ($id,$hostname,$user,$pass) = split(",",$line);
                my %data;
                $data{"hostname"} = $hostname;
                $data{"user"} = $user;
                $data{"pass"} = $pass;
                $result{$id} = \%data;
        }
        close(FILE);

        return \%result;
}

sub dataHandler()
{
        my($response, $ua, $h, $data) = @_;
        my $m = "motionsensor:H";
        my $d = "doorbell:H";
        if ($data =~ /($m|$d)/)
        {
                my $react = $1;
                if ($react =~ /$m/)
                {
                        &dumpPic(3,$m);
                }
                else
                {
                        &dumpPic(5,$d);
                }
        }
        return 1;
}

sub dumpPic()
{
        my $count = $_[0];
        my $context = $_[1];
        my $target_dir = $ARGV[3];
        $target_dir =~ s/\/{1,}$//;
        $target_dir = $target_dir."/";

        if (!(-e $target_dir))
        {
                die "Directory ".$target_dir." does not exist!\n";
        }

        my $request_string = 'http://'.${$device{$id}}{"hostname"}.'/bha-api/image.cgi';
        my $request = GET $request_string;
        $request->authorization_basic(${$device{$id}}{"user"},${$device{$id}}{"pass"});

        for (my $i = 1;$i <= $count;$i++)
        {
                &log("Sending request ($i/$count - $context): ".$request_string);
                my $response = $ua->request($request);

                if ($response->is_success) {
                        &dumpFile($target_dir,${$device{$id}}{"hostname"},$response->decoded_content);
                }
                else {
                        die $request.": ".$response->status_line;
                }
        }
}
