#!/usr/bin/ruby
#
# Get a list of countries / states for the geocaching form.
#
require 'cgi'
require 'geocode'
require 'shadowget'
require 'time'

$debugMode = 1

class CountryState
  include Common
  include Messages

  @@base_url = 'http://www.geocaching.com/seek/nearest.aspx'

  def initialize
    @ttl = 86400 * 180
  end

  def getPage(url, post_vars)
    page = ShadowFetch.new(url)
    page.localExpiry = @ttl
    if post_vars
      page.postVars=post_vars.dup
    end

    if (page.fetch)
      return page.data
    else
      return nil
    end
  end

  def getCountriesPage()
    post_vars, options = parseSearchPage(@@base_url, nil)
    option, key = findOptionAndValue(options, "By Country")
    debug "Changing #{option} from #{post_vars[option]} to #{key}"
    post_vars[option] = key

    post_vars, options = parseSearchPage(@@base_url, post_vars)
    return [post_vars, options]
  end

  def getCountryValues()
    post_vars, options = getCountriesPage()
    options.each_key do |option|
      if option =~ /selectCountry/
        return options[option]
      end
    end
  end

  def getCountryList()
    return getCountryValues.map { |y| y[1] if y[0] != '-1'}
  end

  def findMatchingCountry(try_country)
    countries = getCountryList()
    found = []
    countries.each do |country|
      if country =~ /#{try_country}/i
        found << country
      end
    end
    return found
  end

  def getStatesPage(country)
    post_vars, options = getCountriesPage()
    found_country = nil
    options.each_key do |option|
      if option =~ /selectCountry/
        options[option].each do |key, desc|
          if key == country or desc == country
            debug "Setting country option #{option} to #{key} (#{desc})"
            found_country = key
            post_vars[option] = key
          end
        end
      end
    end

    if not found_country
      displayError "Could not find country: #{country}"
      puts options.inspect
      return nil
    end

    post_vars, options = parseSearchPage(@@base_url, post_vars)
    return [post_vars, options]
  end

  def getStatesList(country)
    post_vars, options = getStatesPage(country)
    options.each_key do |option|
      if option =~ /selectState/
        return options[option]
      end
    end
  end

  # Find the country option, return it's value
  def findOptionAndValue(options, keyword)
    options.each_key do |option|
      options[option].each do |key, desc|
        if desc =~ /#{keyword}/i
          return [option, key]
        end
      end
    end
  end

  def parseSearchPage(url, post_vars)
    data = getPage(url, post_vars)
    current_select_name = nil
    post_vars = Hash.new
    options = Hash.new

    data.each_line {|line|
      if line =~ /^\<input type=\"hidden\" name=\"([^\"]*?)\".* value=\"([^\"]*?)\" \/\>/
        debug "found hidden post variable: #{$1}=#{$2}"
        post_vars[$1] = $2
      elsif line =~ /^\<input type=\"submit\" name=\"([^\"]*?)\".* value=\"([^\"]*?)\"/
        debug "found submit post variable: #{$1}=#{$2}"
        post_vars[$1] = $2
      elsif line =~ /\<select name=\"([^\"]*?)\"/
        current_select_name = $1
        options[current_select_name] = []
      elsif line =~ /\<option selected=\"selected\" value=\"([^\"]*?)\".*?\>(.*?)\</
        options[current_select_name] << [$1, $2]
        if current_select_name
          debug "found selected option for #{current_select_name} #{$1}=#{$2}"
          post_vars[current_select_name] = $1
        else
          displayError "Found selected <option> #{$1}, but no previous <select> tag."
          return nil
        end
      elsif line =~ /\<option.*value=\"([^\"]*?)\".*?\>(.*?)\</
        debug "found option: #{$1}=#{$2}"
        options[current_select_name] << [$1, $2]
      end
    }
    return [post_vars, options]
  end
end

