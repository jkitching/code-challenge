require 'json'
require 'nokogiri'
require 'uri'

class GoogleSerpParser
  BASE_URL = 'https://www.google.com/'

  def initialize(file)
    @doc = Nokogiri::HTML5(File.read(file))
    @img_scripts = @doc.css('script').map(&:text)
      .select {|s| s.include?('setImagesSrc')}
  end

  # The page may contain multiple instances of g-scrolling-carousel.
  # This function is explicitly designed to handle the horizontally
  # scrolling carousel which lives inside of #extabar.
  def parse_carousel()
    category_name = parse_category_name()
    carousel = @doc.at_css('#extabar g-scrolling-carousel')
    return {} unless carousel
    { category_name => carousel.css('a').map { |el| parse_item(el) }  }
  end

  # The knowledge graph path appears right before g-scrolling-carousel:
  #   Vincent van Gogh > Paintings
  #   Canada / Prime ministers
  #
  # Retrieve the last piece of text inside of #extabar that occurs before
  # g-scrolling-carousel.  This will correspond to:
  #   Paintings
  #   Prime ministers
  def parse_category_name()
    @doc.at_xpath(
      '(//*[@id="extabar"]//*[
         not(preceding::g-scrolling-carousel) and
         not(ancestor-or-self::g-scrolling-carousel)
       ]/text())[normalize-space()][last()]'
    )&.text&.downcase&.gsub(/\W/, '-') || 'unknown'
  end

  def parse_item(el)
    short_name = el['aria-label']
    # Remove any whitespace and brackets surrounding extension text.
    extension_m = el['title'][short_name.size..].match('^\W*\((.*)\)\W*$')
    # The order specified here is significant when converting the hash to JSON.
    ret = { name: short_name }
    ret[:extensions] = [extension_m[1]] if extension_m
    ret[:link] = el['href'] ? URI.join(BASE_URL, el['href']).to_s : nil
    ret[:image] = get_image(el.at_css('img')['id'])
    ret
  end

  def get_image(id)
    return unless id
    regex = %r|(data:image/[^;]+;[^;]+?)';var[^;]+'#{id}|
    @img_scripts.map { |script| script.match(regex) { |m| m[1] } }
      .compact.first&.gsub('\\', '')
  end
end

if __FILE__ == $PROGRAM_NAME
  puts JSON.pretty_generate GoogleSerpParser.new(ARGV[0]).parse_carousel
end