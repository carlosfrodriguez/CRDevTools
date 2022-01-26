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

package Console::Command::Dev::LDAP::Group::Generate;

use strict;
use warnings;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = ();

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Generate LDAP Groups with members definitions for LDIF and OTRS config.');
    $Self->AddOption(
        Name        => 'org',
        Description => "Specify the name of the organization (o).",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
        Multiple    => 0,
    );
    $Self->AddOption(
        Name        => 'org-unit',
        Description => "Specify the names of the organizational units (ou).",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
        Multiple    => 1,
    );
    $Self->AddOption(
        Name        => 'name',
        Description => "Specify the name of the group (cn).",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
        Multiple    => 0,
    );
    $Self->AddOption(
        Name        => 'number',
        Description => "Specify the amount of groups to create.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d/smx,
        Multiple    => 0,
    );
    $Self->AddOption(
        Name        => 'member',
        Description => "Specify the names of the group members (member cn).",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
        Multiple    => 1,
    );
    $Self->AddOption(
        Name        => 'member-org-unit',
        Description => "Specify the name of the group members organizational unit (member ou).",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
        Multiple    => 0,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;
    $Self->Print("<yellow>Generating Groups...</yellow>\n\n");

    my $Organization  = $Self->GetOption('org');
    my @OrgUnits      = @{ $Self->GetOption('org-unit') };
    my $Name          = $Self->GetOption('name');
    my $Number        = $Self->GetOption('number') || 1;
    my @Members       = @{ $Self->GetOption('member') };
    my $MemberOrgUnit = $Self->GetOption('member-org-unit');

    my $OrgUnitStr = join ',',  map {"ou=$_"} @OrgUnits;
    my $MembersStr = join "\n", map {"uniquemember: cn=$_,ou=$MemberOrgUnit,o=$Organization"} @Members;

    my $LDIFGroup    = '';
    my $OTRSGroup    = '';
    my $OTRSRole     = '';
    my $OTRSGroupCmd = '';
    my $OTRSRoleCmd  = '';
    for my $Count ( 1 .. $Number ) {

        my $FullName = $Number == 1 ? $Name : "${Name}_${Count}";

        # Preaprare LDFI groups output
        $LDIFGroup .= << "EOF";
dn: cn=$FullName,$OrgUnitStr,o=$Organization
objectclass: groupOfUniqueNames
objectclass: top
cn: $FullName
EOF

        if ($MembersStr) {
            $LDIFGroup .= "$MembersStr";
        }

        $LDIFGroup .= "\n\n";

        # Prepare OTRS Group sync config output
        my $OTRSGroupName = lc $FullName;
        $OTRSGroupName =~ s{\s}{}msx;
        $OTRSGroup .= << "EOF";
        'cn=$FullName,$OrgUnitStr,o=$Organization' => { '$OTRSGroupName' => { rw => 1, ro => 1, }, },
EOF

        # Prepare OTRS Role sync config output
        my $OTRSRoleName = lc($FullName) . 'role';
        $OTRSRoleName =~ s{\s}{}msx;
        $OTRSRole .= << "EOF";
        'cn=$FullName,$OrgUnitStr,o=$Organization' => { '$OTRSRoleName' => 1, },
EOF

        # Prepare Group creation output
        $OTRSGroupCmd .= "bin/otrs.Console.pl Admin::Group::Add --name $OTRSGroupName\n";

        # Prepare Group creation output
        $OTRSRoleCmd .= "bin/otrs.Console.pl Admin::Role::Add --name $OTRSRoleName\n";
    }

    $Self->Print("<yellow>  Generating LDIF config lines...</yellow>\n\n");
    $Self->Print("$LDIFGroup\n");
    $Self->Print("  Copy and Paste the lines above in your LDAP .ldif file.\n\n");

    $Self->Print("<yellow>  Generating OTRS group sync config lines...</yellow>\n\n");
    $Self->Print("$OTRSGroup\n");
    $Self->Print("  Copy and Paste the lines above in your OTRS configuration file.\n");
    $Self->Print("  Inside 'AuthSyncModule::LDAP::UserSyncGroupsDefinition[1..9]'key.\n\n");

    $Self->Print("<yellow>  Generating OTRS group add console commands...</yellow>\n\n");
    $Self->Print("$OTRSGroupCmd\n");
    $Self->Print("  Execute the above commands to create the groups in OTRS.\n");

    $Self->Print("<yellow>  Generating OTRS role sync config lines...</yellow>\n\n");
    $Self->Print("$OTRSRole\n");
    $Self->Print("  Copy and Paste the lines above in your OTRS configuration file.\n");
    $Self->Print("  Inside 'AuthSyncModule::LDAP::UserSyncRolesDefinition[1..9]'key.\n\n");

    $Self->Print("<yellow>  Generating OTRS role add console commands...</yellow>\n\n");
    $Self->Print("$OTRSRoleCmd\n");
    $Self->Print("  Execute the above commands to create the roles in OTRS.\n");

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;
