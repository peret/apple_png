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

      normalize(apple_png_file)
    end
  end

  def normalize(file_path)
    File.open(file_path, 'rb') do |f|
      header_data = f.read(8)

      # Check if it's a PNG
      if header_data != PNGHEADER
        # logger.error "File is not a PNG" if logger
        # TODO: Raise exception?
        return nil
      end

      chunks = []
      idat_data_chunks = []
      iphone_compressed = false

      while !f.eof?
        # Unpack the chunk
        chunk = {}
        chunk['length'] = f.read(4).unpack("L>").first
        chunk['type'] = f.read(4)
        data = f.read(chunk['length'])  # Can be 0...
        chunk['crc'] = f.read(4).unpack("L>").first

        # logger.debug "Chunk found :: length: #{chunk['length']}, type: #{chunk['type']}" if logger

        # This chunk is first when it's an iPhone compressed image
        if chunk['type'] == 'CgBI'
          iphone_compressed = true
        end

        # Extract the header
        #   Width:              4 bytes
        #   Height:             4 bytes
        #   Bit depth:          1 byte
        #   Color type:         1 byte
        #   Compression method: 1 byte
        #   Filter method:      1 byte
        #   Interlace method:   1 byte
        if chunk['type'] == 'IHDR' && iphone_compressed
          @width = data[0, 4].unpack("L>").first
          @height = data[4, 4].unpack("L>").first
          @bit_depth = data[8, 1].unpack("C").first
          @filter_method = data[11, 1].unpack("C").first
          # logger.info "Image size: #{@width}x#{@height} (#{@bit_depth}-bit)" if logger
        end

        # Extract and mutate the data chunk if needed (can be multiple)
        if chunk['type'] == 'IDAT' && iphone_compressed
          idat_data_chunks << data
          next
        elsif idat_data_chunks.length > 0
          # All the IDAT chunks must be consecutive. Consequently, if we reach this point, we've
          # already seen at least one.
          idat_data = idat_data_chunks.join('')
          uncompressed = zlib_inflate(idat_data)

          # Let's swap some colors
          new_data = ''
          (0...@height).each do |y|
            i = new_data.length

            # With filter method 0, the only one currently defined, we have to prepend a filter type byte to each scan line.
            # Currently, we just copy what was there before (though this could be wrong).
            new_data += uncompressed[i]

            (0...@width).each do |x|
              i = new_data.length

              # Swap BGRA to RGBA
              new_data += uncompressed[i + 2]  # Red
              new_data += uncompressed[i + 1]  # Green
              new_data += uncompressed[i + 0]  # Blue
              new_data += uncompressed[i + 3]  # Alpha
            end
          end

          # Compress the data again after swapping (this time with the headers, CRC, etc)
          # TODO: Split into multiple IDAT chunks
          idat_data = zlib_deflate(new_data)
          idat_chunk = {
            'type' => 'IDAT',
            'length' => idat_data.length,
            'data' => idat_data,
            'crc' => Zlib::crc32('IDAT' + idat_data)
          }
          chunks << idat_chunk
        end

        chunk['data'] = data
        chunks << chunk
      end  # EOF

      # Rebuild the image without the CgBI chunk
      out = header_data
      chunks.each do |chunk|
        next if chunk['type'] == 'CgBI'
        # logger.debug "Writing #{chunk['type']}" if logger

        out += [chunk['length']].pack("L>")
        out += chunk['type']
        out += chunk['data']
        out += [chunk['crc']].pack("L>")
      end
      out
    end  # File.open
  end

  private

  def zlib_inflate(string)
    zstream = Zlib::Inflate.new(-Zlib::MAX_WBITS)
    buf = zstream.inflate(string)
    # zstream.finish
    zstream.close
    buf
  end

  def zlib_deflate(string, level = Zlib::DEFAULT_COMPRESSION)
    zstream = Zlib::Deflate.new(level)
    buf = zstream.deflate(string, Zlib::FINISH)
    zstream.close
    buf
  end
end
