require 'sinatra'
require 'sqlite3'
require 'json'
require 'securerandom'
require 'pony'
require 'digest'
require 'time'

def gravatar email
  hash = Digest::MD5.hexdigest(email.strip.downcase)
  "http://www.gravatar.com/avatar/#{hash}?s=40"
end

if File.exists? "comments.db"
  db = SQLite3::Database.new "comments.db"
else
  db = SQLite3::Database.new "comments.db"
  db.execute("CREATE TABLE comments (post_key TEXT, email TEXT, name TEXT, body TEXT, timestamp TEXT, secret TEXT, visible INTEGER, blog_key TEXT);")
end

if !File.exists? "email_logs.db"
  email_logs = SQLite3::Database.new "email_logs.db"
  email_logs.execute("CREATE TABLE email_logs (dest TEXT, secret TEXT, status TEXT, error TEXT, timestamp TEXT);")
  email_logs.close
end

set :bind, '0.0.0.0'
set :port, ENV['COMMENTS_PORT']
set :protection, :except => [:json_csrf]

get '/comments/:blog_key/:post_key' do
  blog_key = params[:blog_key]
  post_key = params[:post_key]
  results = []
  db.execute("select name, email, timestamp, body from comments where blog_key = ? and post_key = ? and visible = 1 order by timestamp", [blog_key, post_key]) do |row|
    results.push({
      :name => row[0],
      :avatar_url => gravatar(row[1]),
      :timestamp => row[2],
      :formatted_date => Date.parse(row[2])strftime("%b %d %Y"),
      :body => row[3]
    })
  end
  headers "Access-Control-Allow-Origin" => "*"
  headers "Content-Type" => "application/json"
  return JSON.generate(results)
end

post '/comments' do
  if request.content_type == 'application/json'
    json = JSON.parse(request.body.read)
    is_bot = json['is_bot']
    secret = json['secret']
    return if is_bot
    blog_key = json['blog_key']
    post_key = json['post_key']
    email = json['email']
    name = json['name']
    body = json['body']
  else
    is_bot = params[:is_bot]
    secret = params[:secret]
    return if is_bot
    blog_key = params[:blog_key]
    post_key = params[:post_key]
    email = params[:email]
    name = params[:name]
    body = params[:body]
  end

  if secret
    db.execute("update comments set visible = 1 where secret = ?", secret)
    headers "Content-Type" => "text/plain"
    return "Comment confirmed"
  else
    timestamp = Time.now.utc.strftime("%Y-%m-%d %H:%M:%S")
    secret = SecureRandom.hex
    db.execute(
      "insert into comments (blog_key, timestamp,email,body,post_key,name,secret,visible) values (?,?,?,?,?,?,?,0)",
      [blog_key, timestamp, email, body, post_key, name, secret]
    )
    Thread.new do
      logs = SQLite3::Database.new "email_logs.db"
      logs.execute(
        "insert into email_logs (dest,secret,status,timestamp) values (?,?,?,?)",
        [email, secret, 'sending', timestamp]
      )
      row_id = logs.last_insert_row_id
      begin
        Pony.mail(
          :to => email,
          :from => ENV['COMMENTS_FROM_ADDRESS'],
          :subject => "Please confirm your submitted blog comment",
          :html_body => <<-EOT
<p>Greetings from the Ad Hoc Blog Comment System,</p>

<p>
If you would like to confirm your submitted comment please click
the confirmation button below.
</p>

<p>
If you think this email was sent to you in error please ignore it.
</p>

<form action="#{ENV['COMMENTS_CALLBACK_URL']}/comments" method="POST">
<button type="submit" name="secret" value="#{secret}">Confirm Comment</button>
</form>
EOT
        )
      rescue => e
        logs.execute(
          "update email_logs set status='error', error=? where rowid=?",
          [e.inspect, row_id]
        )
      else
        logs.execute(
          "update email_logs set status='complete' where rowid=?",
          [row_id]
        )
      ensure
        logs.close
      end
    end
    headers "Content-Type" => "text/plain"
    return "Look for an email to confirm your comment"
  end
end
