#!/bin/bash
#####################################################
#	Checkpoint Source Routing Management
#	Clean Up Script
#
# Written By: Brad Gibson
# Date: September 08, 2009
#
# Features:
#		+ Removes entry from /etc/iproute2/rt_tables
#		+ Removes all routes from routing table (including default)
#		+ Remove all source routing rules using "ip rule delete"
#		+ Flush route cache (ip route flush cache)
# Running:
#		This script is designed to be run soley in the
#		need to entirely remove a secondary routing table
#		(to disable source routing)
#
#		
#####################################################

# Define Variables
	TABLE_DELETE=cogent
	TABLE_PREFIX=202

# Remove routes from table (ip route delete)
	echo ":: Removing routes from table '$TABLE_DELETE'"
	ip route show table $TABLE_DELETE | grep -Ev '^local|^broadcast|^ff|^unreachable|^fe' | while read ROUTE; do
		sync_grep=$(ip route show table $TABLE_DELETE | grep "$ROUTE")
		if [ -n "$sync_grep" ]; then
			ip route delete $ROUTE table $TABLE_DELETE
			sync_grep=$(ip route show table $TABLE_DELETE | grep "$ROUTE")
			if [ -n "$sync_grep" ]; then
				echo "  =: Failed to delete route: $ROUTE"
			else
				echo "  =: Removed route: $ROUTE"
			fi
		else
			echo "  =: Route found: $ROUTE"
		fi
	done
	echo "  =: Complete!"

# Remove source routing rules (ip rule delete)
	echo ":: Checking rules for source routing"
	success_count=0
	total_count=0
	found_count=0
	failed_count=0
	IFS=$'\n'
	ip_rules=($(ip rule show | grep $TABLE_DELETE | sed -e 's/[0-9]*\:\t//'))
	ip rule show | grep $TABLE_DELETE | awk -v k="cogent" '$0 ~ k { print "  =: Removing: " substr($0,8); print "ip rule delete " substr($0,8) | "bash" }'
	for net in "${ip_rules[@]}"; do
		if [ -n "$net" ]; then	
			#echo "  =: Removing: '$net'"
			rule_grep=$(ip rule show | grep "$net")
			if [ -n "$rule_grep" ]; then
				((failed_count++))
			else
				((success_count++))
			fi
		else
			echo "  =: Rule Not Found: '$net'"
			((found_count++))
		fi 
		((total_count++))
	done
	unset IFS
	echo "  =: Results: $success_count/$failed_count/$found_count/$total_count (success/fail/found/total)"
	echo "  =: Complete!"


# Remove table entry in /etc/iproute2/rt_tables
	echo ":: Checking '/etc/iproute2/rt_tables' for table '$TABLE_DELETE'"
	rt_grep=$(grep "$TABLE_DELETE" /etc/iproute2/rt_tables)
	if [ -n "$rt_grep" ]; then
		echo -e "  =: Removing Table: '$TABLE_DELETE'"
		sed -i~ -e s/"$TABLE_PREFIX".*$// /etc/iproute2/rt_tables
		rt_grep=$(grep "$TABLE_DELETE" /etc/iproute2/rt_tables)
		if [ -n "$rt_grep" ]; then
			echo "  =: Failed!"
		else
			echo "  =: Successful!"
		fi
	else
		echo "  =: Table Not Found!"
	fi
	echo "  =: Complete!"

# Flush route cache
	echo ":: Flushing route cache"
	ip route flush cache &> /dev/null
	echo "  =: Complete!"

# Finish
echo ":: Source Routing Configured!"
