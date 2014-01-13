# encoding: utf-8
Encoding.default_external = 'UTF-8'
Encoding.default_internal = 'UTF-8'

require 'slim'
require 'sass'
require 'sass/exec'
require 'coffee-script'

Slim::Engine.set_default_options pretty: true

def coffee2js src_fpath, dst_fpath
  js = CoffeeScript.compile File.read(src_fpath)
  File.write(dst_fpath, js)
end

def sass2css src_fpath, dst_fpath
  opts = Sass::Exec::Sass.new([src_fpath,dst_fpath])
  opts.parse
end

def slim2html src_fpath, dst_fpath

  content_slim = File.read(src_fpath)
  @content_html = compile_slim(src_fpath,content_slim)

  basename = File.basename(src_fpath, ".*")

  if @current_conf
    conf = @current_conf[basename]
    layout_attr = conf[:layout] if conf
  end
    
  if layout_attr
    unless layout_attr == :no
      layout_fpath = File.join(@current_dir,'layout_'+layout.to_s+'.slim')                            
      layout_slim = File.read(layout_fpath)
    end
  else
    layout_fpath = @current_layout_path
    layout_slim = @current_layout
  end
  html =
    if layout_slim
      compile_slim(layout_fpath,layout_slim)
    else
      @content_html
    end
  File.write(dst_fpath, html)
end

def number_text text
  bar = '─────────────────────'
  lines = [bar]
  count=0
  lines += text.split("\n").map{|l| (count+=1).to_s+':  '+l}
  lines << bar
  lines.join("\n")
end
  

def compile_slim fpath,slim_code
  ruby_code = Slim::Engine.new.call(slim_code)

  begin
    eval(ruby_code)
  rescue Exception => ex
    bar = '─────────────────────'
    lines = [
'■■■■■■■■■■■■■■■■■■■■■',
'Exception in:  '+fpath,
'■■■■■■■■■■■■■■■■■■■■■']
    lines << bar
    lines << 'Erorr message:'
    lines << bar
    lines << ex.message
    lines << bar
    lines << 'backtrace:'
    lines << bar
    lines << ex.backtrace
    lines << bar
    lines << 'slim:'
    lines << bar
    lines << number_text(slim_code)
    lines << bar
    lines << 'ruby:'
    lines << bar
    lines << number_text(ruby_code)
    lines << bar
    puts lines.join("\n")
  end
end


def rd relative_path
  path = File.join(@current_dir,relative_path.to_s)
  dir,basename = File.split(path)
  path = File.join(dir,'_'+basename+'.slim')
  compile_slim path, File.read(path)
end

def gen_css_links *links 
  links = [] unless links
  if @css_links
    if @css_links.instance_of?(Array)
      links += @css_links
    else
      links << @css_links
    end
  end
  links.map{|link|
    %{<link rel="stylesheet" type="text/css" href="#{link.to_s}.css">}
  }.join("\n")+"\n"
end

SUFFIX_T = {
  slim: 'html',
  sass: 'css',
  coffee: 'js',
}

def proc_dir src_dpath,dst_dpath
  unless File.exists?(src_dpath)
    puts "Source dir does not exist!!!"
    return
  end
  unless File.exists?(dst_dpath)
    puts "Destination dir does not exist...creating..:"+dst_dpath
    Dir::mkdir(dst_dpath)
  end

  Dir.entries(src_dpath).each{|fname|
    next if fname.start_with?('.')
    next if fname == 'layout.slim'
    @current_dir =src_dpath
    src_fpath = File.join(src_dpath,fname)

    if File::ftype(src_fpath) == 'directory'
      next if /^(wi|img|storehouse)$/ =~ fname
      proc_dir(src_fpath,File.join(dst_dpath,fname))
    else
      conf_fpath = File.join(src_dpath,'sgen_conf.yaml')
      @current_layout_path = layout_fpath = File.join(src_dpath,'layout.slim')
      @current_conf = File.exists?(conf_fpath) ? YAML.load_file(conf_fpath) : nil
      @current_layout = File.exists?(layout_fpath) ? File.read(layout_fpath) : nil
      SUFFIX_T.each{|src_sf,dst_sf|
        src_sf = src_sf.to_s
        if fname.end_with?(src_sf)
          basename = File.basename(fname,'.'+src_sf)
          dst_fpath = File.join(dst_dpath,basename+'.'+dst_sf)
          meth_name = src_sf+'2'+dst_sf
          send(meth_name,src_fpath, dst_fpath)
        end
      }
    end
  }
end


