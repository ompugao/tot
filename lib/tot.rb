# -*- coding: utf-8 -*-
require "tot/version"
require "thor"
require "readline"
require "fileutils"
require "yaml"
require "time"

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

  module TodoManager #{{{
    def load_todo
      todo_path = Config.todo_path
      File.open(todo_path,'w'){|file| YAML.dump([],file)} unless File.exists? todo_path
      YAML.load_file(todo_path)
    end

    def dump_todo todos
      #File.open(Config.todo_path,'w'){|file| file.puts todos.ya2yaml} #YAML.dump(todos, file)}
      # ya2yamlだとhashの順番が変わる
      File.open(Config.todo_path,'w'){|file| YAML.dump(todos, file)}
    end

    def listup(option = :date,&block)
      todo = load_todo
      case option
      when :date
        todo.sort_by{|i| i['date']}
      when :date_reverse
        todo.sort_by{|i| i['date']}.reverse
      else
        todo
      end
    end

    def add_todo(new_todo)
      todo = load_todo
      todo.push new_todo
      dump_todo todo
    end
    module_function :load_todo, :dump_todo, :listup, :add_todo
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
    module_function :datetime_filter
  end #}}}

  class CLI < Thor
    desc 'list' , 'list up your todo'
    method_option :tag, :type => :array
    def list
      TodoManager.listup(:date)
      .keep_if do |todo| 
        unless options[:tag].nil?
          todo['tag'].any?{|i| options[:tag].include? i } 
        else
          true
        end
      end
      .each do |todo| 
        puts [todo['date'].strftime("%Y/%m/%d %H:%M"),todo['title']].join(' ')
      end
    end

    desc 'add' , 'add a task'
    def add
      new_todo = {}
      new_todo['title'] = Readline.readline('title> ', true).chomp('\n')
      new_todo['date'] = Time.parse(Utils.datetime_filter(Readline.readline('date> ', true).chomp('\n')).to_s)
      new_todo['tag'] = Readline.readline('tag (separate by space)> ', true)
                          .chomp('\n').split(' ')
      tmpfile = "/tmp/tot.markdown"
      # File.open(tmpfile,"w"){|file|
      #   file.puts "\n\n# This line will be ignored."
      # }
      system([ENV['EDITOR'],tmpfile].join(' '))
      new_todo['text'] = File.readlines(tmpfile).join
      TodoManager.add_todo new_todo
    end

    desc 'delete', 'delete a task'
    def delete
      todos = TodoManager.listup.each_with_index {|todo,idx| 
        puts ["<<#{idx}>>",todo['date'].strftime("%Y/%m/%d %H:%M"),todo['title']].join(' ')
      }
      todos.delete_at(Readline.readline('Which Task?> ',false).chomp('\n').to_i)
      TodoManager.dump_todo(todos)
    end

    desc 'show TITLE', <<-EOF
show the detail of a task.
TITLE does not need to be complete.
EOF
    def show(title)
      reg = Regexp.new(title)
      todos = TodoManager.listup.keep_if{|item| reg.match(item['title'])}
      if todos.size == 0
        puts 'No matched task.'
      elsif todos.size > 1
        puts 'Several tasks matched.'
      else
        todo = todos[0]
        puts 'Title: ' + todo['title']
        puts 'Date:  ' + todo['date'].strftime("%Y/%m/%d %H:%M")
        puts
        print todo['text']
      end
      
    end
  end
end

