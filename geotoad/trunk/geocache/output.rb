# $Id: output.rb,v 1.20 2002/08/06 11:56:50 strombt Exp $
require 'cgi'
require 'geocache/templates'

class Output
    include Common
    include Display

	$MAX_NOTES_LEN = 1999
	$DetailURL="http://www.geocaching.com/seek/cache_details.aspx?guid="
	$ReplaceWords = {
		'OF'			=> '',
		'A'				=> '',
		'AND'			=> '',
		'ON'			=> '',
		'CACHE'		=> '',
		'FROM'		=> '',
		'GEOCACHE'	=> '',
        'MISSION'   => 'Msn',
		'PARK'		=> 'Pk',
        'IMPOSSIBLE' => 'Imp',
		'THE'			=> '',
		'FOR'			=> '',
		'LAKE'		=> 'Lk',
		'ROAD'		=> 'Rd',
		'RIVER'		=> '',
        'ONE'		=> '1',
		'CREEK'		=> 'Ck',
        'LITTLE'    => 'Lil',
        'BLACK'     => 'Blk',
        'LOOP'      => 'Lp',
        'TRAIL'     => 'Tr',
        'EITHER'    => 'E',
        'BROWN'     => 'Brn',
        'ORANGE'    => 'Org',
		'MOUNTAIN'	=> 'Mt',
        'COUNTY'    => 'Cty',
		'WITH'		=> 'W',
        'DOUBLE'    => 'Dbl',
        'IS'        => '',
        'THAT'      => 'T',
        'IN'        => '',
        'OVERLOOK'  => 'Ovlk'
	}




	## the functions themselves ####################################################

	def initialize
		@output = Array.new
        @waypointLength = 16
        # autodiscovery of gpsbabel output types if it's found!
	end

	def input(data)
		@wpHash=data
	end

	# converts a geocache name into a much shorter name. This algorithm is
	# very sketchy and needs some real work done to it by a brave volunteer.
	def shortName(name)
		tempname = name.dup
		tempname.gsub!('cache', '')
        # acronym.
        if tempname =~ /(\w)\. (\w)\. (\w)/
            debug "shortname: acronym detected.. removing extraneous dots and spaces"
            tempname.gsub!(/\. /, '')
        end


		tempwords=tempname.split(' ')
		newwords=Array.new

        debug "shortname: making a short name from #{name} (now #{tempname})"

		if tempwords.length == 1		# if there is only one word, use it!
            tempname.gsub!(/\W/, '')
            debug "shortname: only one word in #{tempname}, using it"
			#@wpHash[wid]['sname'] = newwords[0]
			return tempname
        else
            debug "#{tempwords.length} words left in this, processing"
		end

		tempwords.each { |word|
			word.gsub!(/\W/, '')
			testWord = word.tr('[a-z]', '[A-Z]')			# lame way for case insensitive
			if $ReplaceWords[testWord]
                debug "shortname: #{word} is changing to #{$ReplaceWords[testWord]}"
				word = $ReplaceWords[testWord]
			elsif (word.length > 6)
                debug "shortname: word #{word} is still long, stripping vowels"
				word = word[0..0] + word[1..15].gsub(/[AEIOUaeiou]/, '')	# remove vowels
			end
			# if it is STILL >wplength
			if word && (word.length > @waypointLength)
                debug "shortname: cutting #{word} in #{name} to #{@waypointLength - 2} chars"
				word.slice!(0,(@waypointLength - 2))
			end

			if word
				newwords.push(word)
			end
		}

        debug "shortname: final result is #{newwords[0..4].to_s}"
		newwords[0..4].to_s
	end

	# select the format for the next set of output
	def formatType=(format)
		if ($Format[format])
			@outputFormat = $Format[format]
			@outputType = format
			debug "format switched to #{format}"
		else
			displayError "[*] Attempted to select invalid format: #{format}"
			return nil
		end
	end

    def waypointLength=(length)
        @waypointLength=length
        debug "set waypoint id length to #{@waypointLength}"
    end

	# exploratory functions.
	def formatList
		formatList = Array.new
		$Format.each_key { |format|
			formatList.push(format)
		}
		formatList
	end


	def formatExtension(format)
		return $Format[format]['ext']
	end

	def formatMIME(format)
		return $Format[format]['mime']
	end

	def formatDesc(format)
		return $Format[format]['desc']
	end


	## sets up for the filtering process ################3
	def prepare (title)
        @title = title

		# if we are not actually generating the output, lets do it in a meta-fashion.
		debug "preparing for #{@outputType}"
		if (@outputFormat['filter_exec'])
			oldformat = @outputType
			src = @outputFormat['filter_src']
			exec = @outputFormat['filter_exec']
            # this should use formatType()
            @outputFormat = $Format[src]
            debug "pre-formatting as #{@outputFormat['desc']}"
			@output = filterInternal(title)
			@outputFormat = $Format[oldformat]
		else
			@output = filterInternal(title)
		end
		return @output
	end

	def writeFile (file)
			file = open(file, "w");
			file.puts(@output)
			file.close
	end

	# writes the output to a file or to a program #############################
	def commit (file)
		debug "committing file type #{@outputType}"
		if @outputFormat['filter_exec']
            displayMessage "Executing #{@outputFormat['filter_exec']}"
			exec = @outputFormat['filter_exec']
			tmpfile = $TEMP_DIR + "/" + @outputType + "." + rand(500000).to_s
			exec.gsub!('INFILE', "\"#{tmpfile}\"")
			exec.gsub!('OUTFILE', "\"#{file}\"")
			writeFile(tmpfile)
			if (File.exists?(file))
				File.unlink(file)
			end

			debug "exec = #{exec}"
			system(exec)
			if (! File.exists?(file))
				displayError "Output filter did not create file #{file}. exec was:"
                displayError "#{exec}"
			end
		else
			debug "no exec"
			writeFile(file)
		end
	end

    def replaceVariables(templateText)
        text = templateText.dup
        # okay. I will fully admit this is a *very* unusual way to handle
        # the templates. This all came to be due to a lot of debugging.
        tags = text.scan(/\<%(\w+\.\w+)%\>/)

        tags.each { |tag|
            # puts "scanning #{tag} (#{@currentWid})"
            (type, var) = tag[0].split('.')
            if (type == "wp")
                text.gsub!(/\<%wp\.#{var}%\>/, @wpHash[@currentWid][var].to_s)
            elsif (type == "out")
                text.gsub!(/\<%out\.#{var}%\>/, @outVars[var].to_s)
            elsif (type == "wpEntity")
                text.gsub!(/\<%wpEntity\.#{var}%\>/, CGI.escapeHTML(@wpHash[@currentWid][var].to_s))
            elsif (type == "outEntity")
                text.gsub!(/\<%outEntity\.#{var}%\>/, CGI.escapeHTML(@outVars[var].to_s))
            else
                displayWarning "unknown type: #{type} tag=#{var}"
            end
        }
        return text
    end


	def filterInternal (title)
		debug "generating output with output: #{@outputType} - #{$Format[@outputType]['desc']}"
		@outVars = Hash.new
        wpList = Hash.new
        @outVars['title'] = title
        @currentWid = 0
        # output is what we generate. We start with the templates pre.
		output = replaceVariables(@outputFormat['templatePre'])


        # this is a strange maintenance loop of sorts. First it builds a list, which
        # I'm not sure what it's used for. Second, it inserts a new item named "sname"
        # which is the caches short name or geocache name.

         @wpHash.each_key { |wid|
            wpList[wid] = @wpHash[wid]['name'].dup

            if (@waypointLength > 1)
                sname = shortName(@wpHash[wid]['name'])

                # This loop checks for any other caches with the same generated waypoint id
                # If a conflict is found, it looks for the unique characters in them, and
                # puts something nice together.
                @wpHash.each_key { |conflictWid|
                    if (@wpHash[conflictWid]['sname']) && (@wpHash[conflictWid]['sname'][0..7] == sname[0..7])
                        debug "Conflict found with #{sname} and #{@wpHash[conflictWid]['snameUncut']}"
                        # Get the first 3 characters
                        unique = ''
                        x = 0

                        # and then the unique ones after that
                        sname.split('').each { |ch|
                            if sname[x] != @wpHash[conflictWid]['snameUncut'][x]
                                unique = unique + sname[x].chr
                                #puts "unique: #{sname[x].chr} does not match #{@wpHash[conflictWid]['sname'][x].chr}"
                            end
                            x = x + 1
                        }

                        if unique.length > 6
                            sname = sname[0..3] + unique
                        else
                            sname = sname[0..(7-unique.length)] + unique
                        end

                        debug "Conflict resolved with short name: #{sname} (unique = #{unique})"
                    end
                }
                @wpHash[wid]['sname'] = sname[0..(@waypointLength - 1)]
                @wpHash[wid]['snameUncut'] = sname
            else
                @wpHash[wid]['sname'] = wid.dup
            end
        }


        # somewhat lame.. HTML specific index that really needs to be in the templates, but I need
        # this done before I go geocaching in 45 minutes.
        if @outputType == "html"
            htmlIndex=''
            debug "I should generate an index, I'm html"

            wpList.sort{|a,b| a[1]<=>b[1]}.each {  |wpArray|
                wid = wpArray[0]
                debug "Creating index for \"#{@wpHash[wid]['name']}\" (#{wid})"

                @wpHash[wid]['details'].gsub!(/\&([A-Z])/, '&amp;(#{$1})');
                htmlIndex = htmlIndex + "<li>"


                if (@wpHash[wid]['travelbug'])
                    htmlIndex = htmlIndex + "<b><font color=\"#11CC11\">$</font></b>"
                end

                if (@wpHash[wid]['terrain'] > 3)
                    htmlIndex = htmlIndex + "<b><font color=\"#229999\">%</font></b>"
                end

                if (@wpHash[wid]['difficulty'] > 3)
                    htmlIndex = htmlIndex + "<b><font color=\"#BB0000\">+</font></b>"
                end

                if (@wpHash[wid]['mdays'] < 0)
                    htmlIndex = htmlIndex + "<b><font color=\"#9900CC\">@</font>"
                end

                htmlIndex = htmlIndex + "<a href=\"\##{wid}\">#{@wpHash[wid]['name']}</a>"

                if (@wpHash[wid]['mdays'] < 0)
                    htmlIndex = htmlIndex + "</b>"
                end

                htmlIndex = htmlIndex + " <font color=\"#444444\">(#{@wpHash[wid]['sname']})</font></li>\n"
            }

            output = output + "<ul>\n" + htmlIndex + "</ul>\n"
        end

        wpList.sort{|a,b| a[1]<=>b[1]}.each {  |wpArray|
            @currentWid = wpArray[0]
            #puts "Output loop: #{@currentWid} - #{@wpHash[@currentWid]['name']}"
			detailsLen = @outputFormat['detailsLength'] || 20000
			numEntries = @wpHash[@currentWid]['details'].length / detailsLen

			@outVars['wid'] = @currentWid.dup
            @outVars['id'] = @wpHash[@currentWid]['sname'].dup
            # This should clear out the hint-dup issue that Scott Brynen mentioned.
            @outVars['hint'] = ''

            if @wpHash[@currentWid]['distance']
                @outVars['relativedistance'] = 'Distance: ' + @wpHash[@currentWid]['distance'].to_s + 'mi ' + @wpHash[@currentWid]['direction']
            end

            if @wpHash[@currentWid]['hint']
                @outVars['hint'] = 'Hint: ' + @wpHash[@currentWid]['hint']
                debug "I will include the hint: #{@outVars['hint']}"
            end

            if (@outVars['id'].length < 1)
                debug "our id is no good, using the wid"
                displayWarning "We could not make an id from \"#{@outVars['sname']}\" so we are using #{@currentWid}"
                @outVars['id'] = @currentWid.dup
            end
			@outVars['url'] = $DetailURL + @wpHash[@currentWid]['sid'].to_s
            if (! @wpHash[@currentWid]['terrain'])
                displayError "[*] Error: no terrain found for #{@currentWid}"
                @wpHash[@currentWid].each_key { |key|
                    displayError "#{key} = #{@wpHash[@currentWid][key]}"
                }
                exit
            end
            if (! @wpHash[@currentWid]['difficulty'])
                displayError "[*] Error: no difficulty found"

                exit
            end
			@outVars['average'] = (@wpHash[@currentWid]['terrain'] + @wpHash[@currentWid]['difficulty'] / 2).to_i
            # This comment is only here to make ArmedBear-J parse the ruby properly: /\*/, "[SPACER]");

			# this crazy mess is all due to iPod's VCF reader only supporting 2k chars!
			0.upto(numEntries) { |entry|
				if (entry > 0)
					@outVars['sname'] = shortName(@wpHash[@currentWid]['name'])[0..12] << ":" << (entry + 1).to_s
				end

				detailByteStart = entry * detailsLen
                detailByteEnd = detailByteStart + detailsLen - 1
				@outVars['details'] = @wpHash[@currentWid]['details'][detailByteStart..detailByteEnd]

                # a bad hack.
                @outVars['details'].gsub!(/\*/, "[SPACER]");
				tempOutput = replaceVariables(@outputFormat['templateWP'])

                # we move this to after our escapeHTML's so the HTML in here doesn't get
                # encoded itself! I think it should be handled a little better than this.
                if (tempOutput)
                    output << tempOutput.gsub(/\[SPACER\]/, @outputFormat['spacer']);
                end
			}
		}

		if @outputFormat['templatePost']
			output << replaceVariables(@outputFormat['templatePost'])
		end

		return output
	end
end

