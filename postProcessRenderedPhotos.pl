#!/usr/bin/perl

use warnings;
use strict;

use File::Glob qw(:glob);
use File::Spec;
use Image::ExifTool qw(:Public);
use MP4::File;
use Time::Local qw(timelocal);
use POSIX qw(strftime);

#--------------------------------------------------------------------------
our @traceLog = ();
our $traceIndent = 0;
my $verbosity = 0;

sub main ();
sub processImage ($);
sub processVideo ($);
sub fixupMetaData ($);
sub getFileArg ($*);
sub readMetadataFile ($);
sub getExifTool ($);
sub psCall ($);
sub writeFile ($@);
sub appendLog (@);
sub trace ($@);

main();
0;

#--------------------------------------------------------------------------
sub main() {
    appendLog("Executing: \"", join('" "', @ARGV), "\"\n");

    my %args = ();
    for (@ARGV) {
        /^[-\/](\w+)=(.*)/ or die "invalid command line option: \"$_\"";
        $args{uc $1} = $2;
    }

    $verbosity = $args{VERBOSITY} || 0;
	
    # clear log of anything from previous file
    local @traceLog = @traceLog;
	
    my $target = "[unknown]";
    eval {
        $target = getFileArg(\%args, TARGET);

        trace(0, "Processing \"$target\" ...\n");
        local $traceIndent = $traceIndent + 1;

        # Replace metadata path with parsed metadata file contents
        $args{METADATA} = readMetadataFile(getFileArg(\%args, METADATA));

        if ($target =~ /\.(?:jpg|tif)$/i) {
            processImage(\%args);
        } elsif ($target =~ /\.(?:mp4)$/i) {
            processMp4(\%args);
        } else {
            die "Don't know how to process file type of $target";
        }

        1;
    } or do {
        # exception occured
        trace(0, "Exception: $@\n");

        unshift(@traceLog, "Failed to process \"$target\"!\n\n");

        appendLog(@traceLog);
        writeFile("$target.fail.log", @traceLog);

        exit(1);
    };

    trace(0, "\n");
}

#--------------------------------------------------------------------------
sub processImage ($) {
    my ($argsRef) = @_;
	
    my $target = getFileArg($argsRef, TARGET);
    my $mdRef = $argsRef->{METADATA};

    my $exifTool = getExifTool($target);

    # 'foo|bar, xyz' --> 'foo/bar, xyz'
    my $flatKeywords = $mdRef->{HIERARCHICALSUBJECT} || $exifTool->GetValue('HierarchicalSubject');
    trace(1, "HierarchicalSubject: $flatKeywords\nKeywords: ", $exifTool->GetValue('Keywords'), "\n");
    $flatKeywords =~ s/\|/\//g if ($flatKeywords);

    my @keywords = split(/[;,]\s*/, $flatKeywords);
	
    # Add lens info as a keyword
    my $lens = $exifTool->GetValue('Lens');
    if ($lens) {
        $lens =~ s/^EF//;			# strip off leading EF
        $lens =~ s/f(?:[\/\\|.])?(\d)/F$1/i;	# change f/2.8 to F2.8 (avoid hierarchy delim)
        $lens =~ s/\.0([\s-])/$1/g;		# strip off trailing .0 at the end of focal length
        push(@keywords, "Lens/$lens");
    }

    # Things under the 'People' keyword hive are people
    my @people = ();
    /^People.*\/([^\/]+)$/i and push(@people, $1) for @keywords;

    #my $ratingPercent = (0,1,25,50,75,99)[$exifTool->GetValue('Rating')];

    trace(0, "Setting keywords to:\n", map { "  \"$_\"\n" } @keywords);
    trace(0, "Setting people to\n",   map { "  \"$_\"\n" } @people);

    $exifTool->SetNewValue('XMP:Subject', \@keywords);
    $exifTool->SetNewValue('Keywords', \@keywords);
    $exifTool->SetNewValue('XPKeywords', \@keywords);
    $exifTool->SetNewValue('RegionPersonDisplayName', \@people);

    # Set date modified to target's DateTaken
    $exifTool->SetNewValue(FileModifyDate => $exifTool->GetValue('DateTimeOriginal'), Protected => 1);
	
    $exifTool->WriteInfo($target) or die "Couldn't write $target: $!";
    -s $target or die "Failed to output \"$target\"";

    # For some reason WriteInfo is not setting FileModifyDate
    $exifTool->SetFileModifyDate($target);

    # TODO: replace this windows implementation on mac if the above is a problem
    # ExifTool uses the current daylight savings time zone adjustment
    # rather than that of the date being set. So use something better
    # for that. Can't use this for others because WIC via PropSys has
    # metadata size limitations that are easily hit.
    #psCall("\"$target\" -System.DateModified:=System.Photo.DateTaken");
}

#--------------------------------------------------------------------------
sub processMp4($) {
    my ($argsRef) = @_;
	
    my $target = getFileArg($argsRef, TARGET);
    my $mdRef = $argsRef->{METADATA};
    
    $mp4 = MP4::File->new;
    $mp4->Modify($target);
}

#--------------------------------------------------------------------------
sub processVideo($) {
    my ($argsRef) = @_;
	
    my $target = getFileArg($argsRef, TARGET);
    my $exifTool = getExifTool($target);
    my $mdRef = $argsRef->{METADATA};

    my $options = '';

    if ($_ = $mdRef->{RATING}) {
        trace(1, "Changing rating to $_\n");
        # reference: RATING_*_STARS_SET defines from propkey.h
        $options .= " -System.Rating=" . (0,1,25,50,75,99)[$_];
    }

    if ($_ = $mdRef->{HIERARCHICALSUBJECT}) {
        s/\|/\//g;
        trace(1, "Changing keywords to $_\n");
        $options .= " \"-System.Keywords=$_\"";
    }

    if ($_ = $mdRef->{DATETIMEISO8601} || $mdRef->{DATETIMEDIGITIZEDISO8601} || $mdRef->{DATETIMEORIGINALISO8601}) {
        s/Z$//; # These should be interpreted as local time, not GMT
        trace(1, "Changing date to $_\n");
        $options .= " -System.DateModified=$_ -System.Document.DateCreated=$_ -System.Document.DateSaved=$_ -System.ItemDate=$_ -System.Media.DateEncoded=$_";
    }

    if ($_ = $mdRef->{GPS}) {
        # convert "lat,long" decimal pair to two degree/minute/second strings
        my @coords = split ',';
        trace(1, "Changing gps to lat=$coords[0] and long=$coords[1]\n");
        $options .= " \"-System.GPS.Latitude=$coords[0]\" \"-System.GPS.Longitude=$coords[1]\"";
    }

    if ($_ = $mdRef->{GPSALTITUDE}) {
        trace(1, "Changing gps altitude to $_\n");
        $options .= " -System.GPS.Altitude=$_";
    }
	
    psCall("\"$target\"$options");
}

#--------------------------------------------------------------------------
sub readMetadataFile ($) {
    my ($metadataPath) = @_;

    my %metadata = ();

    open(my $metadataFile, '<', $metadataPath) or die "Failed to open $metadataPath: $!";
    while (<$metadataFile>) {
        /^(\w+)=(.*)/ or die "Invalid line in file: $_";
        $metadata{uc $1} = $2;
    }
    close($metadataFile) or die "Failed to close $metadataPath: $!";

    return \%metadata;
}





















#--------------------------------------------------------------------------
sub getFileArg ($*) {
    my ($argsRef, $arg) = @_;

    my $file = $argsRef->{uc $arg} || die "$arg required";
    -s $file or die "$file missing";
    return $file;
}

#--------------------------------------------------------------------------
sub getExifTool ($) {
    my ($path) = @_;

    my $exifTool = new Image::ExifTool;
    $exifTool->ExtractInfo($path) or die "Failed to extract info for $path: $!";
    trace(0, 'Extracted "', $exifTool->GetValue('FileName'), "\"\n");
	
    return $exifTool;
}

#--------------------------------------------------------------------------
sub psCall ($) {
    my ($cmdLine) = @_;

    my $command = join('', (File::Spec->splitpath($0))[0,1], "pscall.exe $cmdLine");
    trace(0, "Executing: $command\n");
    #system($command) == 0 or die "Command failed $command: $!";
    my @output = `$command 2>&1`;
    my $result = $?;
    trace(1, @output);
    $result == 0 or die "Command failed $command: $!";
}

#--------------------------------------------------------------------------
sub writeFile ($@) {
    my $filename = shift;

    open(my $file, '>', $filename) or die "Failed to open $filename: $!";
    print $file @_;
    close($file) or die "Failed to close $filename: $!";
}

#--------------------------------------------------------------------------
sub appendLog (@) {
    (my $filename = $0) =~ s/[^\\\/]*$/log.txt/;

    open(my $file, '>>', $filename) or die "Failed to open $filename: $!";
    print $file @_;
    close($file) or die "Failed to close $filename: $!";
}

#--------------------------------------------------------------------------
sub trace ($@) {
    my $level = shift;
    my (undef, undef, $line) = caller;
    my $prefix = sprintf "[%d @ % 3d]%s| ", $level, $line, ' ' x $traceIndent; 
    my @output = ($verbosity > 0) ? map { "$prefix$_\n" } map { split /\n/ } join('', @_) : @_;
    push(@traceLog, @output);
    print @output if $verbosity >= $level;
}
