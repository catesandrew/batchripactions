#!/usr/bin/env sh

# main.command
# Batch Rip Dispatcher

#  Created by Robert Yamada on 11/12/09.
#  Changes:
#  0-20091118-0

#  Copyright (c) 2009 Robert Yamada, All Rights Reserved.

#	This program is free software: you can redistribute it and/or modify
#	it under the terms of the GNU General Public License as published by
#	the Free Software Foundation, either version 3 of the License, or
#	(at your option) any later version.

#	This program is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU General Public License for more details.

#	You should have received a copy of the GNU General Public License
#	along with this program.  If not, see <http://www.gnu.org/licenses/>.

function appleScriptDialog () {
	cat << EOF | osascript -l AppleScript
		-- SET DISABLED OF BATCH RIP DISPATCHER
		-- CANCEL AFTER 30 SECONDS OF NO INPUT
	 --tell application "System Events"
		tell application "Automator Runner"
	activate
	if "$1" is "enabled" then
		set activeButton to 2
		set changeState to "Disable"
	else if "$1" is "disabled" then
		set activeButton to 3
		set changeState to "Enable"
	end if
	display dialog "  Batch Rip Dispatcher is currently" & space & "$1" & return & "  Choose" & space & changeState & space & "to change its current state" & return & "  Choose > Reset to reset Batch Rip Dispatcher" buttons {"Reset", "Disable", "Enable"} default button activeButton giving up after 30 with icon 0 --with title "Batch Rip Dispatcher"
	if the button returned of the result is "Disable" then
		return "Disable"
	else if the button returned of the result is "Enable" then
		return "Enable"
	else if the button returned of the result is "Reset" then
		return "Reset"
	end if
end tell
EOF
}

function disableFolderAction () {
	cat << EOF | osascript -l AppleScript
		-- SET DISABLED OF FOLDER ACTION
	try
		tell application "System Events"
			set scriptname to "Batch Rip • Batch Rip (Folder Action).workflow"
			set enabled of (script named scriptname of folder action named "Volumes") to false
			set scriptname to "Batch Rip • Batch Rip.workflow"
			set enabled of (script named scriptname of folder action named "Volumes") to false
		end tell
	end try
EOF
}


#############################################################################
MAIN SCRIPT

# Disable Folder Action
disableFolderAction &

# Get current state of Batch Rip Dispatch LaunchAgent
batchRipDispatcherPath="$HOME/Library/LaunchAgents/com.batchRip.BatchRipDispatcher.plist"
currentState=`launchctl list com.batchRip.BatchRipDispatcher`
if [ -z "$currentState" ]; then
	currentState="disabled"
else
	currentState="enabled"
fi

# Get selection from user
returnInput=`appleScriptDialog "$currentState"`

# Set Disabled value of com.BatchRipDispatcher to user selection
if [ "$returnInput" = "Enable" ]; then
	# Copy BatchRipDispatcher.plist to ~/Library/LaunchAgents if it doesn't exit
	test -z "$HOME/Library/LaunchAgents" || mkdir "$HOME/Library/LaunchAgents" || cp "$HOME/Library/Automator/Batch Rip Dispatcher.action/Contents/Resources/com.batchRip.BatchRipDispatcher.plist" "$batchRipDispatcherPath"
	getPlistArgument=`defaults read "$HOME/Library/LaunchAgents/com.batchRip.BatchRipDispatcher" "ProgramArguments"`
	test -z "$getPlistArgument" || defaults write "$HOME/Library/LaunchAgents/com.batchRip.BatchRipDispatcher" "ProgramArguments" -array-add "$HOME/Library/Automator/Batch Rip Dispatcher.action/Contents/Resources/batchRipDispatcher.sh"
	# Set launchd user override.plist to Disabled key to false
	launchctl load -w "$batchRipDispatcherPath"

elif [ "$returnInput" = "Disable" ]; then
	# Set launchd user override.plist to Disabled key to true
	launchctl unload -w "$batchRipDispatcherPath"

elif [ "$returnInput" = "Reset" ]; then
	# Set launchd user override.plist to Disabled key to true
	launchctl unload -w "$batchRipDispatcherPath"
	test -z "$HOME/Library/LaunchAgents/com.batchRip.BatchRipDispatcher.plist" || rm -f "$HOME/Library/LaunchAgents/com.batchRip.BatchRipDispatcher.plist"
	test -z /tmp/batchRip || rm -rf /tmp/batchRip
	automator "$HOME/Library/Services/Batch Rip • Batch Rip Dispatcher.workflow"
else
	# Display Error if no input is returned
	osascript -e 'tell application "Automator Runner" to activate & display alert "Error: Batch Rip Dispatcher" message "Error: Did not receive any input from user."'
fi
