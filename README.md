# Ad Hoc Blog Comments System

Put a form on your page which posts something like

```
email=user@example.com&
name=User+Jones&
blog_key=this-blog's-name&
post_key=this-post's-title&
post_key=this-post's-title&
body=This is a comment.
```

to wherever this sinatra web server is running. It should respond immedaitely
with a message like "Check your email to confirm your comment." The email
will container a disclaimer and a button which posts a secret key to the same
url. Posting the secret will make the previously submitted comment visible.

Visible to what? Do a GET with the path
/comments/this-blog's-name/this-post's-title to get a json array of comments
for this post, sorted by timestamp. (email not included in response). Show
these comments on the page dynamically with Javascript.

The confirmation email is sent directly to the user with pony, which uses
sendmail by default. For this to work you need to have email working on
your domain.

The comments are stored in an SQLite database that is created on startup
if it doesn't exist.
