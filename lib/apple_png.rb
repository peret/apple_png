class NotValidApplePngError < StandardError; end

class ApplePng
  attr_accessor :width, :height
  attr_reader :raw_data

  # Create a new ApplePng instance from Apple PNG data in a string
  # @param apple_png_data [String] Binary string containing Apple PNG data, probably read from a file
  def initialize(apple_png_data)
    self.get_dimensions(apple_png_data)
    @raw_data = apple_png_data
  end

  # Get the PNG data as string. The conversion from Apple PNG data to standard PNG data will be performed when this method is first called.
  # @return [String] Binary string containing standard PNG data
  def data
    @data = convert_apple_png if @data.nil?
    @data
  end

  def convert_apple_png
    Dir.mktmpdir do |tmpdir|
      apple_png_file = File.join(tmpdir, 'apple.png')
      File.open(apple_png_file, 'wb') do |file|
        file.write(@raw_data)
      end

      result_file = File.join(tmpdir, 'uncrushed.png')
      uncrush_cmd = "xcrun -sdk iphoneos pngcrush -revert-iphone-optimizations #{apple_png_file} #{result_file}"

      pid, _, _, _ = Open4.popen4(uncrush_cmd)
      _, status = Process.waitpid2 pid
      return nil if status.exitstatus != 0

      File.read(result_file)
    end
  end
end
