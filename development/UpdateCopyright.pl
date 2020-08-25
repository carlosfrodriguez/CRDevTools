#!/usr/bin/env perl
# --
# Copyright (C) 2020 Carlos Rodriguez, https://github.com/carlosfrodriguez
# --
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --
# DO NOT USE THIS FILE ON PRODUCTION SYSTEMS!
#
# otrs is Copyright (C) 2001-2020 OTRS AG, http://otrs.com/

## nofilter(TidyAll::Plugin::OTRS::Perl::Time)

use strict;
use warnings;

use Fcntl qw(:flock);
use POSIX qw(strftime);

# use ../ as lib location
use File::Basename;
use FindBin qw($RealBin);

use vars (qw($Self));

my @FilesInDirectory = DirectoryRead(
    Directory => './',
    Filter    => '*',
);

my $Year = strftime "%Y", localtime;

FILE:
for my $File (@FilesInDirectory) {
    my $ContentSCALARRef = FileRead(
        Location => $File,
    );

    next FILE if ( -d $File );

    my $NewContent = ${$ContentSCALARRef};
    if ( !$NewContent ) {
        print STDERR "Debug $File \n";    # TODO: Delete developer comment
    }
    $NewContent =~ s{(\#\sCopyright\s\(C\)\s)(\d{4})(\sCarlos\sRodriguez,\shttps://github.com/carlosfrodriguez)}
        {$1$Year$3}gmx;

    $NewContent =~ s{(\#\sotrs\sis\sCopyright\s\(C\)\s2001-)(\d{4})(\sOTRS\sAG,\shttp://otrs.com/)}
        {$1$Year$3}gmx;

    next FILE if $NewContent eq ${$ContentSCALARRef};

    my $FileLocation = FileWrite(
        Location => $File,
        Content  => \$NewContent,
    );

    print "Updated $File\n";
}

=head2 FileRead() This function is based in OTRS Kernel::Main::DirectoryRead

to read files from file system

    my $ContentSCALARRef = FileRead(
        Location  => 'c:\some\location\file2read.txt',
    );

=cut

sub FileRead {
    my %Param = @_;

    my $FH;

    # set open mode
    my $Mode = '<:utf8';

    # return if file can not open
    if ( !open $FH, $Mode, $Param{Location} ) {    ## no critic
        my $Error = $!;

        # Check if file exists only if system was not able to open it (to get better error message).
        if ( !-e $Param{Location} ) {
            print STDERR "File '$Param{Location}' doesn't exist!\n";
        }
        else {
            print STDERR "Can't open '$Param{Location}': $Error\n";
        }
        return;
    }

    # lock file (Shared Lock)
    if ( !flock $FH, LOCK_SH ) {
        if ( !$Param{DisableWarnings} ) {
            print STDERR "Can't lock '$Param{Location}': $!\n";
        }
    }

    # read file as string
    my $String = do { local $/; <$FH> };
    close $FH;

    return \$String;
}

=head2 FileWrite() This function is based in OTRS Kernel::Main::FileWrite

to write data to file system

    my $FileLocation = $MainObject->FileWrite(
        Location  => 'c:\some\location\file2write.txt',
        Content   => \$Content,
    );

=cut

sub FileWrite {
    my %Param = @_;

    # filename clean up
    $Param{Location} =~ s/\/\//\//g;

    # set open mode (if file exists, lock it on open, done by '+<')
    my $Exists;
    if ( -f $Param{Location} ) {
        $Exists = 1;
    }
    my $Mode = '+<:utf8';

    # return if file can not open
    my $FH;
    if ( !open $FH, $Mode, $Param{Location} ) {    ## no critic
        print STDERR "Can't write '$Param{Location}': $!\n";
        return;
    }

    # lock file (Exclusive Lock)
    if ( !flock $FH, LOCK_EX ) {
        print STDERR "Can't lock '$Param{Location}': $!\n";
    }

    # empty file first (needed if file is open by '+<')
    truncate $FH, 0;

    # write file if content is not undef
    if ( defined ${ $Param{Content} } ) {
        print $FH ${ $Param{Content} };
    }

    # write empty file if content is undef
    else {
        print $FH '';
    }

    # close the filehandle
    close $FH;

    # set permission
    chmod( oct('0660'), $Param{Location} );

    return $Param{Location};
}

=head2 DirectoryRead() # This function is copyrighted by OTRS (Kernel::Main::DirectoryRead)

reads a directory and returns an array with results.

    my @FilesInDirectory = DirectoryRead(
        Directory => $Path,
        Filter    => '*',
    );

=cut

sub DirectoryRead {
    my %Param = @_;

    # executes glob for every filter
    my @GlobResults;
    my %Seen;

    # prepare non array filter
    if ( ref $Param{Filter} ne 'ARRAY' ) {
        $Param{Filter} = [ $Param{Filter} ];
    }

    for my $Filter ( @{ $Param{Filter} } ) {
        my @Glob = glob "$Param{Directory}/$Filter";

        # look for repeated values
        NAME:
        for my $GlobName (@Glob) {

            next NAME if !-e $GlobName;
            if ( !$Seen{$GlobName} ) {
                push @GlobResults, $GlobName;
                $Seen{$GlobName} = 1;
            }
        }
    }

    # loop protection to prevent symlinks causing lockups
    $Param{LoopProtection}++;
    return if $Param{LoopProtection} > 100;

    # check all files in current directory
    my @Directories = glob "$Param{Directory}/*";

    DIRECTORY:
    for my $Directory (@Directories) {

        # return if file is not a directory
        next DIRECTORY if !-d $Directory;

        # repeat same glob for directory
        my @SubResult = DirectoryRead(
            %Param,
            Directory => $Directory,
        );

        # add result to hash
        for my $Result (@SubResult) {
            if ( !$Seen{$Result} ) {
                push @GlobResults, $Result;
                $Seen{$Result} = 1;
            }
        }
    }

    # if no results
    return if !@GlobResults;

    # always sort the result
    my @Results = sort @GlobResults;

    return @Results;
}
