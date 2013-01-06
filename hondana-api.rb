# -*- coding: utf-8 -*-
# -*- ruby -*-

require 'rubygems'
require 'active_record'
require 'sinatra'

require 'enzan'

# Enzan.new('http://hondana.org','/Users/masui/hondana')

ActiveRecord::Base.establish_connection(
  :adapter => 'mysql',
  :host => 'localhost',
  :username => 'root',
  :password => '',
  :database => 'hondana',
  :encoding => 'utf8'
)

class Shelf < ActiveRecord::Base
  has_many :entries
end

class Book < ActiveRecord::Base
  has_many :entries
end

class Entry < ActiveRecord::Base
  belongs_to :book
  belongs_to :shelf
end

get '/shelves' do
  isbns = params[:isbn]
  patterns = params[:pattern]
  if isbns then
    # shelves?isbn=ISBN1,ISBN2
    names = {}
    isbns.split(/,/).each { |isbn|
      book = Book.find(:first, :conditions => ["isbn = ?",isbn])
      book.entries.each { |entry|
        names[entry.shelf.name] = 1
      }
    }
    names.keys.to_json
  elsif patterns then
    # /shelves?pattern=パタン1,パタン2
    names = {}
    patterns.split(/,/).each { |pattern|
      Shelf.find(:all).each { |shelf|
        names[shelf.name] = 1 if /#{pattern}/.match(shelf.name)
      }
    }
    names.keys.to_json
  else
    # /shelves
    Shelf.find(:all).collect { |shelf|
      shelf.name
    }.to_json
  end
end

get '/books' do
  shelves = params[:shelf]
  patterns = params[:pattern]
  if shelves then
    # books?shelf=本棚1,本棚2
    names = {}
    shelves.split(/,/).each { |shelf|
      shelf = Shelf.find(:first, :conditions => ["name = ?",shelf])
      shelf.entries.each { |entry|
        names[entry.book.isbn] = 1
      }
    }
    names.keys.to_json
  elsif patterns then
    # /books?pattern=パタン1,パタン2
    names = {}
    patterns.split(/,/).each { |pattern|
      re = /#{pattern}/
      Book.find(:all).each { |book|
        names[book.isbn] = 1 if re.match(book.title)
        names[book.isbn] = 1 if re.match(book.isbn)
        names[book.isbn] = 1 if re.match(book.authors)
      }
    }
    names.keys.to_json
  else
    # /books
    Book.find(:all).collect { |book|
      book.isbn
    }.find_all { |isbn|
      # 何故かISBNがnilなエントリがあったので
      isbn
    }.to_json
  end
end

# /bookinfo?isbn=ISBN
get '/bookinfo' do
  Book.find(:first, :conditions => ["isbn = ?", params[:isbn]]).to_json
end

# /shelfinfo?shelf=本棚名
get '/shelfinfo' do
  Shelf.find(:first, :conditions => ["name = ?",params[:shelf]]).to_json
end

# /entry?isbn=ISBN&shelf=本棚名
get '/entry' do
  book = Book.find(:first, :conditions => ["isbn = ?",params[:isbn]])
  shelf = Shelf.find(:first, :conditions => ["name = ?",params[:shelf]])
  Entry.find(:first, :conditions => ["shelf_id = ? and book_id = ?", shelf.id, book.id]).to_json
end

# #
# # 本棚演算API
# #
# # 例:
# #   /enzan/"yuco".shelves.books                  'yucoの本棚'の本のリスト
# #   /enzan/"yuco".shelves.similarshelves.books   'yucoの本棚'に似た本棚にある本のリスト
# #   /enzan/"24798102040".books.shelves           ISBNが24798102040である本が登録してある本棚リスト
# #
# get '/enzan/:command' do |command|
#   # Books.new('yuco').to_json
#   eval(command).to_json
# end
# 
# # ランダムに本棚情報を返す
# get '/randomshelf' do
#   shelves = Shelf.find(:all)
#   [shelves[rand(shelves.length)].name].to_json
# end
# 
# # ランダムに類似本棚情報を返す
# get '/:entry/randomshelf' do |entry|
#   shelves = (entry =~ /^[\dX]+$/ ? entry.books.similarshelves : entry.shelves.similarshelves)
#   a = shelves.to_a # shelvesは特殊データ形式なので
#   [shelves.to_a[rand(a.length)]].to_json
# end
# 
# # ランダムに書籍情報を返す
# get '/randombook' do
#   books = Book.find(:all)
#   book = books[rand(books.length)]
#   [[book.isbn,book.title,book.imageurl]].to_json
# end
# 
# # ランダムに類似書籍情報を返す
# get '/:entry/randombook' do |entry|
#   isbns = (entry =~ /^[\dX]+$/ ? entry.books.similarbooks : entry.shelves.similarbooks).to_a
#   isbn = isbns[rand(isbns.length)]
#   book = Book.find(:first, :conditions => ["isbn = '#{isbn}'"])
#   [[book.isbn,book.title,book.imageurl]].to_json
# end
# 
# #
# # DB検索API
# #
# 
# # /(本棚名)/booklist
# # とりあえず100件に制限
# get '/:shelfname/booklist' do |shelfname|
#   Shelf.find(:first, :conditions => ["name = '#{shelfname}'"]).entries[0...100].collect { |entry|
#     book = entry.book
#     [book.isbn, book.title, book.imageurl]
#   }.to_json
# end
# 
# # /(ISBN)/bookinfo
# get /\/([\dX]+)\/bookinfo/ do |isbn|
#   Book.find(:first, :conditions => ["isbn = '#{isbn}'"]).to_json
# end
# 
# # /(ISBN)/shelflist
# get /\/([\dX]+)\/shelflist/ do |isbn|
#   Book.find(:first, :conditions => ["isbn = '#{isbn}'"]).entries.collect { |entry|
#     entry.shelf.name
#   }.to_json
# end
# 
# # /(本棚名)/(ISBN)
# get /\/(.*)\/([\dX]+)/ do |shelfname,isbn|
#   @isbn = isbn
#   @shelfname = shelfname
#   @book = Book.find(:first, :conditions => ["isbn = ?",isbn])
#   @shelf = Shelf.find(:first, :conditions => ["name = ?",shelfname])
#   Entry.find(:first, :conditions => ["shelf_id = ? and book_id = ?", @shelf.id, @book.id]).to_json
# end
# 
# # /(ISBN)/similarbooks
# get /([\dX]+)\/similarbooks/ do |isbn|
#   similarbooks = isbn.books.similarbooks
#   similarbooks.collect { |isbn|
#     book = Book.find(:first, :conditions => ["isbn = '#{isbn}'"])
#     [book.isbn, book.title, book.imageurl]
#   }.to_json
# end
# 
# # /(本棚名)/similarbooks
# get '/:shelfname/similarbooks' do |shelfname|
#   similarbooks = shelfname.shelves.similarbooks
#   similarbooks.collect { |isbn|
#     book = Book.find(:first, :conditions => ["isbn = '#{isbn}'"])
#     [book.isbn, book.title, book.imageurl]
#   }.to_json
# end
# 
# # /(ISBN)/similarshelves
# get /([\dX]+)\/similarshelves/ do |isbn|
#   similarshelves = isbn.books.similarshelves
#   similarshelves.collect { |shelf|
#     shelf
#   }.to_json
# end
# 
# # /(ISBN)/comments
# get /([\dX]+)\/comments/ do |isbn|
#   Book.find(:first, :conditions => ["isbn = '#{isbn}'"]).entries.find_all { |entry|
#     entry.comment != ""
#   }.collect { |entry|
#     [entry.shelf.name, entry.comment]
#   }.to_json
# end
# 
# #
# # メイン
# #
# 
# get '/:shelfname' do
#   @shelfname = params[:shelfname]
#   erb :navi3
# end


