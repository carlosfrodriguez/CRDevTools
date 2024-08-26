# --
# Copyright (C) 2022 Carlos Rodriguez, https://github.com/carlosfrodriguez
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --
# DO NOT USE THIS FILE ON PRODUCTION SYSTEMS!
#
# otrs is Copyright (C) 2001-2022 OTRS AG, http://otrs.com/
# --

package Console::Command::Dev::Config::InlineEditing;

use strict;
use warnings;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::SysConfig',
    'Kernel::System::YAML',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Set / Unset Inline Editing for properties in business objects detail views.');
    $Self->AddOption(
        Name        => 'set',
        Description => "To set (1) or unset (0) inline editing",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/0|1/smx,
        Multiple    => 0,
    );

    # TODO: Maybe extend options to include certain business objects only.

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Updating inline editing...</yellow>\n");

    # TODO: extend all the possible widget objects
    # TODO: also enable dynamic fields (e.g. AgentFrontend::Ticket::InlineEditing::Property###DynamicField)
    my %BusinessObjects = (
        Ticket => {
            ObjectSetting => 'AgentFrontend::TicketDetailView::WidgetType###Properties',

            # DFSetting => 'AgentFrontend::Ticket::InlineEditing::Property###DynamicField'
        },
    );

    my $SysConfigObject = $Kernel::OM->Get('Kernel::System::SysConfig');
    my $YAMLObject      = $Kernel::OM->Get('Kernel::System::YAML');

    my $GlobalSuccess = 1;

    for my $BOName ( sort keys %BusinessObjects ) {

        $Self->Print("<yellow>Updating $BOName...</yellow>");

        my @SettingsToUpdate;

        for my $SettingType ( sort keys %{ $BusinessObjects{$BOName} } ) {
            my $SettingName = $BusinessObjects{$BOName}->{$SettingType};

            my %CurrentSetting = $SysConfigObject->SettingGet(
                Name => $SettingName,
            );

            my $EffectiveValue;
            if ( $SettingType eq 'ObjectSetting' ) {
                $EffectiveValue = $CurrentSetting{EffectiveValue};

                my $Config = $YAMLObject->Load( Data => $EffectiveValue->{Config} );

                PROPERTY:
                for my $Property ( @{ $Config->{Properties} } ) {

                    next PROPERTY if ( substr( $Property->{Name}, 0, length('DynamicField_') ) eq 'DynamicField_' );
                    $Property->{IsInlineEditable} = 1;
                }

                $EffectiveValue->{Config} = $YAMLObject->Dump( Data => $Config );

                push @SettingsToUpdate, {
                    Name           => $SettingName,
                    EffectiveValue => $EffectiveValue,
                    IsValid        => 1,
                };
            }

            my $Success = $SysConfigObject->SettingsSet(
                UserID   => 1,
                Comments => "Updated inline editing for properties setting for object $BOName",
                Settings => \@SettingsToUpdate,
            );
            if ( !$Success ) {
                $GlobalSuccess = 0;
            }

            my $Result = ( $Success ? "<green>OK</green>" : "<red>Fail</red>" ) . "\n";

            $Self->Print("$Result");
        }
    }

    if ( !$GlobalSuccess ) {
        $Self->PrintError("Inline property editing was not updated for all business objects.\n");
        return $Self->ExitCodeError();
    }

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;
