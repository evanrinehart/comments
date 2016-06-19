require 'sinatra'
require 'sqlite3'
require 'json'
require 'securerandom'
require 'pony'

if File.exists? "comments.db"
  db = SQLite3::Database.new "comments.db"
else
  db = SQLite3::Database.new "comments.db"
  db.execute("CREATE TABLE comments (id ROWID, post_key TEXT, email TEXT, name TEXT, body TEXT, timestamp TEXT, secret TEXT, visible INTEGER, blog TEXT);")
end

set :bind, '0.0.0.0'
set :port, 7777

get '/comments/:blog/:post_key' do
  blog = params[:blog]
  post_key = params[:post_key]
  results = []
  db.execute("select * from comments where blog = ? and post_key = ? and visible = 1 order by timestamp", [blog, post_key]) do |row|
    results.push({
      :name => row[3],
      :timestamp => row[5],
      :body => row[4]
    })
  end
  return JSON.generate(results)
end

post '/comments' do
  is_bot = params[:is_bot]
  secret = params[:secret]
  return if is_bot
  if secret
    db.execute("update comments set visible = 1 where secret = ?", secret)
    return "Comment confirmed"
  else
    blog = params[:blog]
    post_key = params[:post_key]
    email = params[:email]
    name = params[:name]
    body = params[:body]
    timestamp = Time.now.utc.strftime("%Y-%m-%d %H:%M:%S")
    secret = SecureRandom.hex
    db.execute(
      "insert into comments (blog, timestamp,email,body,post_key,name,secret,visible) values (?,?,?,?,?,?,0)",
      [blog, timestamp, email, body, post_key, name, secret]
    )
    Pony.mail(
      :to => email,
      :from => "noreply@evanr.info",
      :subject => "Please confirm your submitted blog comment",
      :body => <<-EOT
<p>Greetings from the Ad Hoc Blog Comment System,</p>

<p>
If you would like to confirm your submitted comment please click
the confirmation button below.
</p>

<p>
If you think this email was sent to you in error please ignore it.
</p>

<form action="http://evanr.info:4567/comments" method="POST">
<button type="submit" name="secret" value="#{secret}">Confirm Comment</button>
</form>
EOT
    )
    return "Look for an email to confirm your comment"
  end
end