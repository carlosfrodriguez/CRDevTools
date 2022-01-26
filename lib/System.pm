# --
# Copyright (C) 2020 Carlos Rodriguez, https://github.com/carlosfrodriguez
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --
# DO NOT USE THIS FILE ON PRODUCTION SYSTEMS!
#
# otrs is Copyright (C) 2001-2020 OTRS AG, http://otrs.com/
# This software is based in otrs module-tools package
# --

package System;

use strict;
use warnings;

use File::Basename qw(dirname);
use File::Spec();

our @ObjectDependencies = ();

=head1 NAME

System - several helper functions

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SystemConsoleObject = $Kernel::OM->Get('System');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # 0=off; 1=on;
    $Self->{Debug} = $Param{Debug} || 0;

    return $Self;
}

=head2 GetHome()

gets the home directory of the development tools.

    my $Home = System::GetHome();

=cut

sub GetHome {
    return dirname( dirname( File::Spec->rel2abs(__FILE__) ) );
}

=head2 ObjectInstanceCreate()

creates a new object instance

    my $Object = System::ObjectInstanceCreate(
        'My::Package',      # required
        ObjectParams => {   # optional, passed to constructor
            Param1 => 'Value1',
        },
        Silent => 1,        # optional (default 0) - disable exceptions
    );

Please note that this function might throw exceptions in case of error.

=cut

sub ObjectInstanceCreate {
    my ( $Self, $Package, %Param ) = @_;

    if ( !$Package ) {
        die "Could not find Console Command.";
    }

    my $FileName = $Package;
    $FileName =~ s{::}{/}g;
    $FileName .= '.pm';
    my $RequireSuccess = eval {
        ## nofilter(TidyAll::Plugin::OTRS::Perl::Require)
        require $FileName;
    };

    if ( !$RequireSuccess ) {
        if ( !$Param{Silent} ) {
            die "Could not require $Package:\n$@";
        }
        return;
    }

    my $Instance = $Package->new( @{ $Param{ObjectParams} // [] } );
    return $Instance if $Instance;

    if ( !$Param{Silent} ) {
        die "Could not instantiate $Package.";
    }
    return;
}

1;
