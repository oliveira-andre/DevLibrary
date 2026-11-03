# One batch of a paged book list. `next_params` is the query for the "See more" link, or
# nil on the last batch (002 data-model.md).
Book::Page = Data.define(:books, :next_params)
