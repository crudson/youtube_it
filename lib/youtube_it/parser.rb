class YouTubeIt
  module Parser #:nodoc:
    class FeedParser #:nodoc:
      def initialize(content)
        @content = open(content).read rescue content
      end

      def parse
        parse_content @content
      end

      def parse_videos
        doc = REXML::Document.new(@content)
        videos = []
        doc.elements.each("*/entry") do |video|
          videos << parse_entry(video)
        end
        videos
      end
    end

    class CommentsFeedParser < FeedParser #:nodoc:
      # return array of comments
      def parse_content(content)
        doc = REXML::Document.new(content.body)
        feed = doc.elements["feed"]

        comments = []
        feed.elements.each("entry") do |entry|
          comments << parse_entry(entry)
        end
        return comments
      end

      protected
      def parse_entry(entry)
        author = YouTubeIt::Model::Author.new(
          :name => entry.elements["author"].elements["name"].text,
          :uri => entry.elements["author"].elements["uri"].text
        )
        YouTubeIt::Model::Comment.new(
          :author => author,
          :content => entry.elements["content"].text,
          :published => entry.elements["published"].text,
          :title => entry.elements["title"].text,
          :updated => entry.elements["updated "].text,
          :url => entry.elements["id"].text
        )
      end
    end

    class PlaylistFeedParser < FeedParser #:nodoc:

      def parse_content(content)
        xml = REXML::Document.new(content.body)
        entry = xml.elements["entry"] || xml.elements["feed"]
        YouTubeIt::Model::Playlist.new(
          :title         => entry.elements["title"].text,
          :summary       => (entry.elements["summary"] || entry.elements["media:group"].elements["media:description"]).text,
          :description   => (entry.elements["summary"] || entry.elements["media:group"].elements["media:description"]).text,
          :playlist_id   => entry.elements["id"].text[/playlist([^<]+)/, 1].sub(':',''),
          :published     => entry.elements["published"] ? entry.elements["published"].text : nil,
          :response_code => content.code,
          :xml           => content.body)
      end
    end

    class PlaylistsFeedParser < FeedParser #:nodoc:

      # return array of playlist objects
      def parse_content(content)
        doc = REXML::Document.new(content.body)
        feed = doc.elements["feed"]
        
        playlists = []
        feed.elements.each("entry") do |entry|
          playlists << parse_entry(entry)
        end
        return playlists
      end
      
      protected
      
      def parse_entry(entry)
        YouTubeIt::Model::Playlist.new(
          :title         => entry.elements["title"].text,
          :summary       => (entry.elements["summary"] || entry.elements["media:group"].elements["media:description"]).text,
          :description   => (entry.elements["summary"] || entry.elements["media:group"].elements["media:description"]).text,
          :playlist_id   => entry.elements["id"].text[/playlist([^<]+)/, 1].sub(':',''),
          :published     => entry.elements["published"] ? entry.elements["published"].text : nil,
          :response_code => nil,
          :xml           => nil)
      end
    end

    class ProfileFeedParser < FeedParser #:nodoc:
      def parse_content(content)
        xml = REXML::Document.new(content.body)
        entry = xml.elements["entry"] || xml.elements["feed"]
        YouTubeIt::Model::User.new(
          :age         => entry.elements["yt:age"] ? entry.elements["yt:age"].text : nil,
          :company         => entry.elements["yt:company"] ? entry.elements["yt:company"].text : nil,
          :gender         => entry.elements["yt:gender"] ? entry.elements["yt:gender"].text : nil,
          :hobbies         => entry.elements["yt:hobbies"] ? entry.elements["yt:hobbies"].text : nil,
          :hometown         => entry.elements["yt:hometown"] ? entry.elements["yt:hometown"].text : nil,
          :location         => entry.elements["yt:location"] ? entry.elements["yt:location"].text : nil,
          :last_login         => entry.elements["yt:statistics"].attributes["lastWebAccess"],
          :join_date         => entry.elements["published"] ? entry.elements["published"].text : nil,
          :movies         => entry.elements["yt:movies"] ? entry.elements["yt:movies"].text : nil,
          :music         => entry.elements["yt:music"] ? entry.elements["yt:music"].text : nil,
          :occupation         => entry.elements["yt:occupation"] ? entry.elements["yt:occupation"].text : nil,
          :relationship         => entry.elements["yt:relationship"] ? entry.elements["yt:relationship"].text : nil,
          :school         => entry.elements["yt:school"] ? entry.elements["yt:school"].text : nil,
          :subscribers         => entry.elements["yt:statistics"].attributes["subscriberCount"],
          :videos_watched         => entry.elements["yt:statistics"].attributes["videoWatchCount"],
          :view_count         => entry.elements["yt:statistics"].attributes["viewCount"],
          :upload_views         => entry.elements["yt:statistics"].attributes["totalUploadViews"]
        )
      end
    end

    class ContactsFeedParser < FeedParser #:nodoc:
      def parse_content(content)
        contacts = []
        doc     = REXML::Document.new(content)
        feed    = doc.elements["feed"]
        if feed
          feed_id            = feed.elements["id"].text
          updated_at         = Time.parse(feed.elements["updated"].text)
          total_result_count = feed.elements["openSearch:totalResults"].text.to_i
          offset             = feed.elements["openSearch:startIndex"].text.to_i
          max_result_count   = feed.elements["openSearch:itemsPerPage"].text.to_i

          feed.elements.each("entry") do |entry|
            contacts << YouTubeIt::Model::Contact.new(
              :status => entry.elements["yt:status"].text,
              :username => entry.elements["yt:username"].text)
          end
        end
        contacts
      end
    end

    class VideoFeedParser < FeedParser #:nodoc:

      def parse_content(content)
        doc = REXML::Document.new(content)
        entry = doc.elements["entry"]
        parse_entry(entry)
      end

      protected
      def parse_entry(entry)
        video_id = entry.elements["id"].text
        published_at  = entry.elements["published"] ? Time.parse(entry.elements["published"].text) : nil
        updated_at    = entry.elements["updated"] ? Time.parse(entry.elements["updated"].text) : nil

        # parse the category and keyword lists
        categories = []
        keywords = []
        entry.elements.each("category") do |category|
          # determine if  it's really a category, or just a keyword
          scheme = category.attributes["scheme"]
          if (scheme =~ /\/categories\.cat$/)
            # it's a category
            categories << YouTubeIt::Model::Category.new(
              :term => category.attributes["term"],
              :label => category.attributes["label"])

          elsif (scheme =~ /\/keywords\.cat$/)
            # it's a keyword
            keywords << category.attributes["term"]
          end
        end

        title = entry.elements["title"].text
        html_content = entry.elements["content"] ? entry.elements["content"].text : nil

        # parse the author
        author_element = entry.elements["author"]
        author = nil
        if author_element
          author = YouTubeIt::Model::Author.new(
            :name => author_element.elements["name"].text,
            :uri => author_element.elements["uri"].text)
        end
        media_group = entry.elements["media:group"]

        # if content is not available on certain region, there is no media:description, media:player or yt:duration
        description = ""
        unless media_group.elements["media:description"].nil?
          description = media_group.elements["media:description"].text
        end

        # if content is not available on certain region, there is no media:description, media:player or yt:duration
        duration = 0
        unless media_group.elements["yt:duration"].nil?
          duration = media_group.elements["yt:duration"].attributes["seconds"].to_i
        end

        # if content is not available on certain region, there is no media:description, media:player or yt:duration
        player_url = ""
        unless media_group.elements["media:player"].nil?
          player_url = media_group.elements["media:player"].attributes["url"]
        end

        unless media_group.elements["yt:aspectRatio"].nil?
          widescreen = media_group.elements["yt:aspectRatio"].text == 'widescreen' ? true : false
        end

        media_content = []
        media_group.elements.each("media:content") do |mce|
          media_content << parse_media_content(mce)
        end

        # parse thumbnails
        thumbnails = []
        media_group.elements.each("media:thumbnail") do |thumb_element|
          # TODO: convert time HH:MM:ss string to seconds?
          thumbnails << YouTubeIt::Model::Thumbnail.new(
            :url => thumb_element.attributes["url"],
            :height => thumb_element.attributes["height"].to_i,
            :width => thumb_element.attributes["width"].to_i,
            :time => thumb_element.attributes["time"])
        end

        rating_element = entry.elements["gd:rating"]
        extended_rating_element = entry.elements["yt:rating"]

        rating = nil
        if rating_element
          rating_values = {
            :min => rating_element.attributes["min"].to_i,
            :max => rating_element.attributes["max"].to_i,
            :rater_count => rating_element.attributes["numRaters"].to_i,
            :average => rating_element.attributes["average"].to_f
          }

          if extended_rating_element
            rating_values[:likes] = extended_rating_element.attributes["numLikes"].to_i
            rating_values[:dislikes] = extended_rating_element.attributes["numDislikes"].to_i
          end

          rating = YouTubeIt::Model::Rating.new(rating_values)
        end

        if (el = entry.elements["yt:statistics"])
          view_count, favorite_count = el.attributes["viewCount"].to_i, el.attributes["favoriteCount"].to_i
        else
          view_count, favorite_count = 0,0
        end

        noembed = entry.elements["yt:noembed"] ? true : false
        racy = entry.elements["media:rating"] ? true : false

        if where = entry.elements["georss:where"]
          position = where.elements["gml:Point"].elements["gml:pos"].text
          latitude, longitude = position.split(" ")
        end

        YouTubeIt::Model::Video.new(
          :video_id => video_id,
          :published_at => published_at,
          :updated_at => updated_at,
          :categories => categories,
          :keywords => keywords,
          :title => title,
          :html_content => html_content,
          :author => author,
          :description => description,
          :duration => duration,
          :media_content => media_content,
          :player_url => player_url,
          :thumbnails => thumbnails,
          :rating => rating,
          :view_count => view_count,
          :favorite_count => favorite_count,
          :widescreen => widescreen,
          :noembed => noembed,
          :racy => racy,
          :where => where,
          :position => position,
          :latitude => latitude,
          :longitude => longitude)
      end

      def parse_media_content (media_content_element)
        content_url = media_content_element.attributes["url"]
        format_code = media_content_element.attributes["yt:format"].to_i
        format = YouTubeIt::Model::Video::Format.by_code(format_code)
        duration = media_content_element.attributes["duration"].to_i
        mime_type = media_content_element.attributes["type"]
        default = (media_content_element.attributes["isDefault"] == "true")

        YouTubeIt::Model::Content.new(
          :url => content_url,
          :format => format,
          :duration => duration,
          :mime_type => mime_type,
          :default => default)
      end
    end

    class VideosFeedParser < VideoFeedParser #:nodoc:

      private
      def parse_content(content)
        videos  = []
        doc     = REXML::Document.new(content)
        feed    = doc.elements["feed"]
        if feed
          feed_id            = feed.elements["id"].text
          updated_at         = Time.parse(feed.elements["updated"].text)
          total_result_count = feed.elements["openSearch:totalResults"].text.to_i
          offset             = feed.elements["openSearch:startIndex"].text.to_i
          max_result_count   = feed.elements["openSearch:itemsPerPage"].text.to_i

          feed.elements.each("entry") do |entry|
            videos << parse_entry(entry)
          end
        end
        YouTubeIt::Response::VideoSearch.new(
          :feed_id => feed_id || nil,
          :updated_at => updated_at || nil,
          :total_result_count => total_result_count || nil,
          :offset => offset || nil,
          :max_result_count => max_result_count || nil,
          :videos => videos)
      end
    end
  end
end

