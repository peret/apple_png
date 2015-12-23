require 'apple_png/apple_png'
require 'zlib'
# require 'logger'

class NotValidApplePngError < StandardError; end

class ApplePng
  attr_accessor :width, :height
  attr_reader :raw_data

  PNGHEADER = "\x89PNG\r\n\x1A\n".force_encoding('ASCII-8BIT')

  # Create a new ApplePng instance from Apple PNG data in a string
  # @param apple_png_data [String] Binary string containing Apple PNG data, probably read from a file
  def initialize(apple_png_data)
    puts "HEEEELLLOO"
    self.get_dimensions(apple_png_data)
    @raw_data = apple_png_data
  end

  # Get the PNG data as string. The conversion from Apple PNG data to standard PNG data will be performed when this method is first called.
  # @return [String] Binary string containing standard PNG data
  def data
    @data = convert if @data.nil?
    @data
  end

  def convert
    Dir.mktmpdir do |tmpdir|
      apple_png_file = File.join(tmpdir, 'apple.png')
      File.open(apple_png_file, 'wb') do |file|
        file.write(@raw_data)
      end
      result_file = File.join(tmpdir, 'apple_converted.png')

      convert_apple_png(apple_png_file, '_converted')
      File.read(result_file)
    end
  end
end
