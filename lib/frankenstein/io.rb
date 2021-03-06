# I/O
module Frankenstein
  KEY_LOG = 'log'
  KEY_PULL = 'pull'
  KEY_REVIEW = 'review'
  KEY_SCAN = 'scan'
  KEY_VISIT = 'visit'

  class << self
    require 'json'
    require 'time'

    def io_records(all)
      r = io_json_read Frankenstein::FILE_VISITS

      unless all
        r = r.reject do |_, value|
          list = value['log']

          m = list.map do |x|
            sc = x['type'] == 'scan'
            pu = x['type'] == 'pull'
            rev = x['type'] == 'review'
            redirects = x['redirects'] == 0
            pu || rev || redirects || sc
          end
          # puts "map = #{m}"
          m.include? true
        end
      end

      r
    end

    def io_record_pull_check(repo)
      return true unless io_record_pull_exists repo

      print "A pull request exists for #{repo.white}, continue? (y/n) "
      user_input = STDIN.gets.chomp
      return false if user_input.downcase != 'y'
      true
    end

    def io_record_pull_exists(repo)
      r = io_json_read Frankenstein::FILE_VISITS
      r[repo]['log'].each { |x| return true if x['type'] == 'pull' }
      false
    end

    def io_record_pull(repo, pull_url)
      pull = {
        type: KEY_PULL,
        date: Time.now.utc.iso8601,
        pull_url: pull_url
      }
      if File.exist? FILE_VISITS
        r = io_json_read FILE_VISITS
        if r.key? repo
          hash = r[repo]
          list = hash[KEY_LOG]
          list.push pull
        else
          r[repo] = { KEY_LOG => [pull] }
        end

        io_json_write FILE_VISITS, r
      else
        puts "io_record_visits no visits log to record pull for #{repo.red}"
      end
    end

    def io_record_review(repo)
      p = {
        type: KEY_REVIEW,
        date: Time.now.utc.iso8601
      }
      if File.exist? FILE_VISITS
        r = io_json_read FILE_VISITS
        if r.key? repo
          hash = r[repo]
          list = hash[KEY_LOG]
          list.push p
        else
          r[repo] = { KEY_LOG => [p] }
        end

        io_json_write FILE_VISITS, r
      else
        puts "io_record_review no visits log to record review for #{repo.red}"
      end
    end

    def io_record_scan(username, repos)
      item = {
        type: KEY_SCAN,
        date: Time.now.utc.iso8601,
        repos: repos
      }
      if File.exist? FILE_VISITS
        r = io_json_read FILE_VISITS
        if r.key? username
          hash = r[username]
          list = hash[KEY_LOG]
          list.push item
        else
          r[username] = { KEY_LOG => [item] }
        end

        io_json_write FILE_VISITS, r
      else
        puts 'io_record_scan file missing'.red
      end
    end

    def io_record_visits(repo, number_of_links, redirects,
      failures, file, repo_info)
      visit = {
        type: KEY_VISIT,
        date: Time.now.utc.iso8601,
        links: number_of_links,
        redirects: redirects.count,
        failures: failures.count,
        file: file
      }
      visit['info'] = repo_info unless repo_info.nil?
      logs = [visit]

      if File.exist? FILE_VISITS
        r = io_json_read FILE_VISITS
        if r.key? repo
          hash = r[repo]
          list = hash[KEY_LOG]
          list.push visit
        else
          r[repo] = { KEY_LOG => logs }
        end

        io_json_write FILE_VISITS, r
      else
        hash = { repo => { KEY_LOG => logs } }

        io_json_write FILE_VISITS, hash
      end
      # puts 'visit recorded '
    end

    def io_repo_log_json(list, log)
      log.add "\nWriting repo log ... "
      json = if File.exist?(FILE_REPO)
               saved = io_json_read FILE_REPO

               list.each do |x|
                 h = saved.map { |s| s if s['repo'] == x[:repo] }.compact.first
                 unless h.nil? || x[:count].nil?
                   difference = x[:count] - h['count']
                   m = "#{x[:repo]} count difference: #{difference} #{em_star}"
                   log.add m unless difference == 0
                   saved.delete(h)
                 end

                 saved.push(x)
               end

               saved
             else
               list
             end
      io_json_write FILE_REPO, json
    end

    def io_json_read(filename)
      c = File.read(filename)
      c ? JSON.parse(c) : nil
    end

    def io_json_write(filename, content)
      json = content.to_json
      File.open(filename, 'w') { |f| f.puts(json) }
    end
  end
end
