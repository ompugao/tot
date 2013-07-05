# Tot

Manage your todo on your terminal, inspired by [console-task-checker](https://github.com/alice1017/console-task-checker).

## Installation

Install it yourself as:

    $ gem install tot

or checkout this repository

    $ git clone https://github.com/ompugao/tot

And then execute:

    $ cd tot
    $ rake install


## Usage

Please set the environmental variable: EDITOR
    
    $ export EDITOR='vim'

### add a task
    
    $ tot add 

<a href="http://www.flickr.com/photos/98458708@N02/9215669896/" title="snapshot_add_task_done by ompugao, on Flickr"><img src="http://farm4.staticflickr.com/3824/9215669896_47f7891590.jpg" width="500" height="358" alt="snapshot_add_task_done"></a>

tot executes EDITOR to edit text.

<a href="http://www.flickr.com/photos/98458708@N02/9212895053/" title="snapshot_add_task_editor by ompugao, on Flickr"><img src="http://farm6.staticflickr.com/5337/9212895053_034b18ae33.jpg" width="500" height="358" alt="snapshot_add_task_editor"></a>

You can see the text of a task by executing:

    $ tot show

You can see the text of tasks by casting list into stdin:

<a href="http://www.flickr.com/photos/98458708@N02/9212895163/" title="snapshot_grep_show by ompugao, on Flickr"><img src="http://farm3.staticflickr.com/2876/9212895163_434c70c1d0.jpg" width="500" height="358" alt="snapshot_grep_show"></a>

When you have done your task, delete it.

    $ tot delete

or 

<a href="http://www.flickr.com/photos/98458708@N02/9215670040/" title="snapshot_grep_delete by ompugao, on Flickr"><img src="http://farm4.staticflickr.com/3775/9215670040_598923afbf.jpg" width="500" height="358" alt="snapshot_grep_delete"></a>

For more detail, Please see

    $ tot help

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
