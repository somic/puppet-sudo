require 'puppet/type/file'

Puppet::Type.type(:file).provide :sudo_hidden_tempfile,
  :parent => Puppet::Provider::File do

  desc "Like file but writes tempfiles that are hidden from sudo"

  def write(property)
    mode = self.should(:mode) # might be nil
    mode_int = mode ? symbolic_mode_to_int(mode, Puppet::Util::DEFAULT_POSIX_MODE) : nil
    # '.' in name will make sudo ignore this file and its tempfiles
    sudo_tempfile ||= "#{self[:path]}.sudotemp"

    if write_temporary_file?
      Puppet::Util.replace_file(sudo_tempfile, mode_int) do |file|
        file.binmode
        content_checksum = write_content(file)
        file.flush
        fail_if_checksum_is_wrong(file.path, content_checksum) if validate_checksum?
        if self[:validate_cmd]
          output = Puppet::Util::Execution.execute(self[:validate_cmd].gsub(self[:validate_replacement], file.path), :failonfail => true, :combine => true)
          output.split(/\n/).each { |line|
            self.debug(line)
          }
        end
      end
    else
      umask = mode ? 000 : 022
      Puppet::Util.withumask(umask) { ::File.open(self[:path], 'wb', mode_int ) { |f| write_content(f) } }
    end

    remove_existing(:file)
    File.rename(sudo_tempfile, self[:path])

    # make sure all of the modes are actually correct
    property_fix
  end

end
