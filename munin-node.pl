#!/usr/bin/perl -T
# /*
#  * munin-node.pl - an implementation of munin-node for win32-cygwin
#  *
#  * Copyright (c) 2015 John Vinopal
#  * Licensed under the MIT license.
#  */
use strict;
use warnings;
use Sys::Hostname;
require 5.010;

$| = 1;
undef $ENV{PATH};
print $0;

# Configuration
my $NAME     = 'munin-node-win32-cygwin';
my $VERSION  = '0.0.1';
my $HOSTNAME = hostname();
$HOSTNAME = "testlap";

# Plugins
my $PLUGIN_DIR = './plugins';
if ($0 =~ m#^(?<path>.*)/#) {
    $PLUGIN_DIR = $+{path} . '/plugins';
}
my @PLUGIN_LIST = getPluginList($PLUGIN_DIR);

# Commands
my %commandFuncs = (
    # Displays willingness to support multigraph plugins.
    # Usage: cap
    # Args: none
    # Returns: none
    'cap'     => sub { print "cap multigraph dirtyconfig\n"; },
    
    # Invokes the given plugin with the "config" argument, producing the
    # graph definition and list of fields.
    # Usage: config <plugin>
    # Args: plugin name
    # Returns: none
    'config'  => sub { executePlugin( $_[0], "config" ); },

    # Invokes the given plugin with no argument, producing the list of field values.
    # Usage: fetch <plugin>
    # Args: plugin name
    # Returns: none
    'fetch'   => sub { executePlugin( $_[0], "" ); },
    
    
    # Displays the plugins for a given node
    # Usage: list [node]
    # Args: optional node name
    # Returns: none
    'list'    => sub { print "@PLUGIN_LIST" if ( not defined $_[0] or $_[0] eq $HOSTNAME ); print "\n"; }, 
    
    # Displays known nodes (only the localhost is supported)
    # Usage: nodes
    # Args: none
    # Returns: none
    'nodes'   => sub { print "$HOSTNAME\n.\n"; },

    # Causes munin-node to exit
    # Usage: quit
    # Args: none
    # Returns: none
    'quit'    => sub { },

    # Displays munin-node version
    # Usage: version
    # Args: none
    # Returns: none
    'version' => sub { print "$NAME on $HOSTNAME version: $VERSION\n"; },

);

### MAIN BODY ###
print "# munin node at $HOSTNAME\n";
chdir($PLUGIN_DIR) or do {
    print "# Failed to chdir to plugin directory\n.\n";
    return;
};
processCommands();
exit;

# Read commands one at a time and process appropriately.
# Args: none
# Returns: none
sub processCommands {
    local $/ = "\n";
    CMDLOOP: while (<>) {
        chomp;
        my ( $cmd, $arg ) = split /\s+/, $_;

        # Validate the command.
        if ( not defined $cmd or not exists $commandFuncs{$cmd} ) {
            help();
            next;
        }
        
        # Abort loop on quit.
        last CMDLOOP if ($cmd eq 'quit');

        # Untaint the argument; it is used as the executable file name.
        my $arg_untainted;
        if ( defined $arg ) {
            ($arg_untainted) = $arg =~ /^([a-z0-9_][a-z0-9_.-]*)\z/i;
        }

        # Call the command function.
        &{ $commandFuncs{$cmd} }($arg_untainted);
    }
}

# Return valid plugins, defined as executable files in the plugin directory.
# Args: plugin directory (absolute or relative path)
# Returns: list of executable files in the plugin directory
sub getPluginList {
    my $PLUGIN_DIR = shift;
    my @PLUGIN_LIST;
    opendir( my $DH, $PLUGIN_DIR ) or die "# failed to read plugins\n.\n";
    while ( readdir($DH) ) {
        if ( -f "$PLUGIN_DIR/$_" && -r _ && -x _ ) {
            push( @PLUGIN_LIST, $_ );
        }
    }
    closedir($DH);
    return @PLUGIN_LIST;
}

# Validate plugin
# Args: plugin name
# Returns: true if plugin exists in the plugin directory
sub isValidPlugin {
    my $plugin = shift;
    return ( defined $plugin and grep( /^$plugin$/, @PLUGIN_LIST ) );
}

# Print some help; called for unknown commands.
# Args: none
# Returns: none
sub help {
    local $, = ", ";
    print "# Unknown command. Try: ";
    print sort keys %commandFuncs;
    print "\n";
}

# Execute a plugin
# Args: plugin name, plugin arg
# Returns: none
sub executePlugin {
    my $plugin = shift;
    my $config = shift;

    # Check plugin for validity.
    if ( not isValidPlugin($plugin) ) {
        print "# Unknown service\n.\n";
        return;
    }

    # Disable warning if the open fails.
    no warnings 'exec';

    # Ignore issues if the far side isn't reading data.
    local $SIG{PIPE} = 'IGNORE';

    # Open a read pipe to the plugin.
    open( my $FH, '-|', "./$plugin $config" ) or do {
        print "# Failed to exec service\n.\n";
        return;
    };

    # Print the plugin's output to STDOUT.
    print <$FH>;
    close($FH);
    print ".\n";
}
