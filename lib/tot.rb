# -*- coding: utf-8 -*-
require "tot/version"
require "thor"
require "readline"
require "fileutils"
require "yaml"
require "time"
require "term/ansicolor"
require "tempfile"
require 'shellwords'

module Tot
  module Config #{{{
    @@CONFIG_FILE = File.join(ENV['HOME'],'.totrc')
    @@TODO_PATH = nil
    def todo_path
      create unless File.exists?(@@CONFIG_FILE)
      @@TODO_PATH = YAML.load_file(@@CONFIG_FILE)['todo_file'] 
    end

    def create
      path = Readline.readline("Input the path to save tasks >> ",false)
      path += ".yaml" unless [".yaml",".yml"].include?(File.extname(path))
      File.open(@@CONFIG_FILE,'w'){|file| YAML.dump({'todo_file' => path}, file)}
    end
    module_function :todo_path,:create
  end #}}}

  class TodoManager #{{{
    include Enumerable
    def initialize
      load_file
    end
    def load_file
      todo_path = Config.todo_path
      File.open(todo_path,'w'){|file| YAML.dump([],file)} unless File.exists? todo_path
      @tasks = YAML.load_file(todo_path).sort_by{|i| i['date']}
    end

    def refresh
      load_file
      self
    end

    def save
      #File.open(Config.todo_path,'w'){|file| file.puts todos.ya2yaml} #YAML.dump(todos, file)}
      # ya2yamlだとhashの順番が変わる
      File.open(Config.todo_path,'w'){|file| YAML.dump(@tasks, file)}
    end

    def add(new_todo)
      @tasks.push new_todo
    end
    
    def each
      @tasks = load_file
      @tasks.each do |todo|
        yield todo
      end
      self
    end

    def delete_at(at)
      @tasks.delete_at at
    end

    def delete_by_title(title)
      @tasks.delete_at(@tasks.find_index{|obj| obj['title'] == title})
      @tasks
    end

    def find_all!(&block)
      @tasks = self.find_all(&block)
    end
    def print_color(with_index = false) #{{{
      @tasks.each_with_index do |todo,idx|
        #https://github.com/flori/term-ansicolor/blob/master/examples/example.rb
        case (Date.parse(todo['date'].to_s) - Date.parse(Time.now.to_s)).to_i
        when -10 .. -1
          print Term::ANSIColor.cyan
        when 0..1
          print Term::ANSIColor.bold, Term::ANSIColor.red
        when 2..3
          print Term::ANSIColor.bold, Term::ANSIColor.yellow
        when 4..7
          print Term::ANSIColor.bold, Term::ANSIColor.magenta
        else
          print Term::ANSIColor.green
        end

        puts [("<<#{idx}>>" if with_index),
              todo['date'].strftime("%Y/%m/%d %H:%M"),
              todo['title'],
              '['+todo['tag'].flatten.join(',')+']'].keep_if{|i| not i.nil?}.join(' | ')
        print Term::ANSIColor.reset
      end
      self
    end #}}}

    # This method is incomplete, returns array of title for now.
    def stdin_parser(lines) #{{{
      lines = lines.split(/\n/) unless lines.class == Array
      lines.map {|line|
        line.chomp.gsub(/\e\[\d+m/,"").split('|').map(&:strip)
      }.keep_if{|i| i != []}
      .map {|l| 
        task = {}
        task[:date] = Time.parse(l[0])
        task[:title] = l[1]
        task[:tag] = YAML.load(l[2])
        task
      }
    rescue
      raise RuntimeError, 'Stdin lines are invalid.'
    end #}}}

    #module_function :load_file, :dump, :listup, :add
  end #}}}

  module Utils #{{{
    def datetime_filter(buf) #{{{
      today = DateTime.now
      ret = nil
      case buf
      when /^(今日)/
        ret = today
      when /^(明日|あした|あす)/
        ret = today + 1
      when /^(明後日|あさって)/
        ret = today + 2
      when /^しあさって/
        ret = today + 3
      when /^(日|月|火|水|木|金|土)曜(日)?/
        # 次の○曜日
        date_offset = ([ '日', '月', '火', '水', '木', '金', '土' ].index($1) - today.wday + 7) % 7
        date_offset += 7 if date_offset == 0
        ret = today + date_offset
      when /^([0-9]+\/[0-9]+\/[0-9]+)/# yyyy/mm/dd
        ret = DateTime.parse($1)
      when /^([0-9]+\/[0-9]+)/# mm/dd
        date = DateTime.parse($1)
        # 過去の日付だったら来年にする
        while date < today
          date = date >> 12
        end
        ret = date
      when /^([0-9]+)/# mmddd
        datestr = $1
        case datestr.length
        when 2
          # 12   => 1/2
          datestr = datestr.slice(0..0) + "/" + datestr.slice(1..1)
        when 3
          # 123  => 1/23 ※ 12/3 の可能性もあるけどそうはしない
          datestr = datestr.slice(0..0) + "/" + datestr.slice(1..2)
        when 4
          # 1230 => 12/30
          datestr = datestr.slice(0..1) + "/" + datestr.slice(2..3)
        else
          raise ArgumentError , "不正な値です"
        end
        date = DateTime.parse(datestr)
        # 過去の日付だったら来年にする
        while date < today
          date = date >> 12
        end
        ret = date
      end
      ret
    end #}}}

    def stdin_incoming? #{{{
      (File.pipe?(STDIN) || File.select([STDIN], [], [], 0) != nil)
    end #}}}

    module_function :datetime_filter,:stdin_incoming?
  end #}}}

  class CLI < Thor
    TTY = open("/dev/tty")
    def initialize(*args)
      super
      @todo_manager = TodoManager.new
      @stdin_tasks = []
      # The following lines needs to be fixed when I correct stdin_parser.
      if Utils.stdin_incoming?
        @stdin_lines = STDIN.readlines
        @stdin_tasks = @todo_manager.stdin_parser(@stdin_lines)
      end
    end

    desc 'list' , 'list up your todo' #{{{
    method_option :tag, :type => :array, :aliases => "-t"
    method_option :filter, :type => :array, :aliases => "-f"
    def list
      if options['tag']
        @todo_manager.find_all! do |todo|
          options[:tag].all?{|i| todo['tag'].include? i}
        end
      elsif options['filter']
        @todo_manager.find_all! do |todo|
           options['filter'].all?{|i|
             re = Regexp.new(i,Regexp::IGNORECASE)
             re.match(todo['title'])
           }
        end
      end
      @todo_manager.print_color(false)
    end #}}}

    desc 'add' , 'add a task' #{{{
    def add
      new_todo = {}
      new_todo['title'] = Readline.readline('title> ', true).chomp('\n').strip
      begin
          new_todo['date'] = Time.parse(Utils.datetime_filter(Readline.readline('date> ', true).chomp('\n')).to_s)
      rescue
          puts "Invalid input. Please retry."
          retry
      end
      new_todo['tag'] = Readline.readline('tag (separate by space)> ', true)
                          .chomp('\n').split(' ')
      # File.open(tmpfile,"w"){|file|
      #   file.puts "\n\n# This line will be ignored."
      # }

      #tmpfile = "/tmp/tot.markdown"
      #system([ENV['EDITOR'],tmpfile].join(' '))
      Tempfile.open(["/tmp/tot_",".markdown"]) do |t|
        IO.copy_stream(STDIN, t) unless STDIN.tty?
        STDIN.reopen(TTY)
        system([ENV['EDITOR'], t.path, ">", TTY.path].join(" "))
        new_todo['text'] = t.read
      end
      #new_todo['text'] = File.readlines(tmpfile).join
      print new_todo['text']
      #File.delete tmpfile
      @todo_manager.add new_todo
      @todo_manager.save
    end #}}}

    desc 'delete', 'delete a task' #{{{
    def delete
      if @stdin_tasks.empty?
        @todo_manager.print_color(true)
        begin
          @todo_manager.delete_at Integer(Readline.readline('Which Task?> ',false).chomp('\n'))
        rescue
          puts 'Invalid input. Please retry.'
          retry
        end
        @todo_manager.save
      elsif #@stdin_tasks.size >= 1
        @stdin_tasks.each do |stdin_task|
          @todo_manager.delete_by_title(stdin_task[:title])
        end
        @todo_manager.save
      end
    end #}}}

    desc 'show', <<-EOF #{{{
show the detail of a task.
TITLE does not need to be complete.
EOF
    method_option :filter, :type => :array, :aliases => "-f",:default => nil
    def show

      #### stdinあり
      if Utils.stdin_incoming?
        todos = []
        @stdin_tasks.each do |stdin_task|
          todos.push @todo_manager.find_all!{|item| stdin_task[:title].match(item['title'])}
        end
        todos.flatten.each { |todo| puts '-'*30;print_todo(todo)}
        return
      end

      #### stdinなし
      reg = nil
      if options['filter']
        reg = Regexp.new(options['filter'].join('.*'),Regexp::IGNORECASE)
      else
        reg = /.*/
      end

      todo = nil
      todos = @todo_manager.find_all!{|item| reg.match(item['title'])}
      if todos.size == 0
        puts 'No matched task.'
        return
      elsif todos.size > 1
        @todo_manager.print_color(true)
        todo = todos[Readline.readline('Which Task?> ',false).chomp('\n').to_i]
      else
        todo = todos.first
      end

      print_todo(todo)
    end #}}}

    desc 'edit', 'edit a task' #{{{
    method_options :text => :boolean, :title => :boolean, :date => :boolean, :tag => :boolean
    method_option :filter, :type => :array, :aliases => "-f",:default => nil
    def edit
      #### stdinあり
      if Utils.stdin_incoming?
        todos = []
        @stdin_tasks.each do |stdin_task|
          todos.push @todo_manager.find_all!{|item| stdin_task[:title] == item['title']}
        end
        todos.flatten.each { |todo| edit_todo(todo,options)}
        return
      end

      #### stdinなし
      reg = nil
      if options['filter']
        reg = Regexp.new(options['filter'].join('.*'),Regexp::IGNORECASE)
      else
        reg = /.*/
      end
      todo = nil
      todos = @todo_manager.find_all!{|item| reg.match(item['title'])}
      if todos.size == 0
        puts 'No matched task.'
        return
      elsif todos.size > 1
        @todo_manager.print_color(true)
        todo = todos[Readline.readline('Which Task?> ',false).chomp('\n').to_i]
      else
        todo = todos.first
      end
      
      edit_todo(todo,options)
    end #}}}

    no_commands do #{{{
      def edit_todo(todo,options={})
        old_title = todo['title']
        if options['title']
          todo['title'] = Readline.readline('New Title> ').chomp('\n')
        elsif options['date']
          begin
            todo['date'] = Time.parse(Utils.datetime_filter(Readline.readline('date> ', true).chomp('\n')).to_s)
          rescue
            puts 'Invalid input. Please retry.'
            retry
          end
        elsif options['tag']
          todo['tag'] = Readline.readline("tag (old_value: #{todo['tag'].join(' ')})> ", true)
          .chomp('\n').split(' ')
        else
          #tmpfile = "/tmp/tot_" + Shellwords.shellescape(todo['title']) + ".markdown"
          tmpfile = "/tmp/tot.markdown"

          fileio = File.open(tmpfile,'w')
          fileio.write todo['text']
          fileio.flush
          fileio.close
          STDIN.reopen(TTY)
          system([ENV['EDITOR'], tmpfile, ">", TTY.path].join(" "))
          todo['text'] = File.readlines(tmpfile).join
          print_todo(todo)

          File.delete tmpfile
        end

        @todo_manager.refresh
        @todo_manager.delete_by_title(old_title)
        @todo_manager.add todo
        @todo_manager.save
      end
    end #}}}

    no_commands do #{{{
      def print_todo(todo)
        puts 'Title: ' + todo['title']
        puts 'Date:  ' + todo['date'].strftime("%Y/%m/%d %H:%M")
        puts
        print todo['text']
      end
    end #}}}
  end
end
