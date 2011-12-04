package BookWeb;
use Dancer ':syntax';
use Dancer::Plugin::DBIC;
use Dancer::Session;

our $VERSION = '0.1';

get '/' => sub {
    my $books_rs = schema->resultset('Book');
    
    my @reading = $books_rs->search({
        started => { '!=', undef },
        ended => undef,
    });

    my @read = $books_rs->search({
        ended => { '!=', undef },
    });

    my @to_read = $books_rs->search({
        started => undef,
    });

    template 'index', {
        reading => \@reading,
        read    => \@read,
        to_read => \@to_read,
        logged  => session 'logged_in',
    };
};

get '/start/:isbn' => sub {
    if (not session 'logged_in') {
        redirect '/login';
    }
    
    my $books_rs = schema->resultset('Book');
    my $book = $books_rs->find({ isbn => param('isbn')});

    if ($book) {
        $book->update({started => DateTime->now});
    }

    return redirect '/';
};

get '/end/:isbn' => sub {
    if (not session 'logged_in') {
        redirect '/login';
    }

    my $books_rs = schema->resultset('Book');
    my $book = $books_rs->find({ isbn => param('isbn')});

    if ($book) {
        $book->update({ended => DateTime->now});
    }

    return redirect '/';
};

get '/add/:isbn' => sub {
    if (not session 'logged_in') {
        redirect '/login';
    }

    my $author_rs = schema->resultset('Author');

    my $amz = Net::Amazon->new(
        token => $ENV{AMAZON_KEY},
        secret_key => $ENV{AMAZON_SECRET},
        locale => 'uk',
    ) or die "Cannot connect to Amazon\n";

    # Search for the book at Amazon
    my $resp = $amz->search(asin => param('isbn'));

    unless ($resp->is_success) {
        die 'Error: ', $resp->message;
    }

    my $book = $resp->properties;
    my $title = $book->ProductName;
    my $author_name = ($book->authors)[0];
    my $imgurl = $book->ImageUrlMedium;

    # Find or create the author
    my $author = $author_rs->find_or_create({
        name => $author_name,
    });

    # Add the book to the author
    $author->add_to_books({
        isbn => param('isbn'),
        title => $title,
        image_url => $imgurl,
    });

    return redirect '/';
};

get '/login' => sub {
    template 'login';  
};

post '/login' => sub {
    if (params->{user} eq 'dave' && params->{pass} eq 'letmein') {
        session 'logged_in' => 1;
    }

    redirect '/';
};

true;
