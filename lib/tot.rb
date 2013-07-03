require "tot/version"
require "thor"
require "readline"
require "fileutils"
require "yaml"

module Tot
  module Config
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
  end

  module TodoManager
    def load_todo
      todo_path = Config.todo_path
      File.open(todo_path,'w'){|file| YAML.dump([],file)} unless File.exists? todo_path
      YAML.load_file(todo_path)
    end

    def listup(option = :deadline_reverse,&block)
      todo = load_todo
      case option
      when :deadline
        todo.sort_by{|i| i.time}
      when :deadline_reverse
        todo.sort_by{|i| i.time}.reverse
      else
        todo
      end
    end
    module_function :load_todo, :listup
  end

  class CLI < Thor
    desc 'list' , 'list up your todo'
    def list
      puts TodoManager.listup
    end

  end
end

