
using DataStructures

# includes:
include("dns2ip.jl")
include("ports_info2dict.jl")
include("threatcrowd2dict.jl")
include("location2dict.jl")

##############################################################

# Node of information about each domain.
struct thread_node
	ip::String
	dns::String
	ports::Dict
    neighbours::Array
    location::Dict
    depth::Int
end

# Dictionary of neighbours of root server.
main_dict = Dict()
# Queue of unexplored servers.
main_queue = Queue{Array}()
# Array of visited vertexes.
main_visited_vertexes = []

##############################################################

function database(root_server::Domain)
    global main_dict

    # probe root
    root_dict = threatcrowd_dict(root_server)
    tmp_neighbours = extract_neighbours(root_dict, 0)
    root_ip = convert_dns2ip(root_server.s)
    tmp_node = thread_node(root_ip, root_server.s, nmap(root_server.s), tmp_neighbours, location(Ip(root_ip)), 0)
    main_dict[root_server.s] = tmp_node
    append!(main_visited_vertexes, [root_server])
    # probe neighbours of root server
    while !isempty(main_queue)
        @show length(main_queue)
        vertex_arr = dequeue!(main_queue)
        vertex = vertex_arr[1]
        depth = vertex_arr[2]
        vertex_dict = threatcrowd_dict(vertex)
        tmp_neighbours = extract_neighbours(vertex_dict, depth)
        if typeof(vertex) == Domain
            vertex_ip = convert_dns2ip(vertex.s)
            tmp_node = thread_node(vertex_ip, vertex.s, nmap(vertex.s), tmp_neighbours, location(Ip(vertex_ip)), depth)
        elseif typeof(vertex) == Ip
            tmp_node = thread_node(vertex.s, "", nmap(vertex.s), tmp_neighbours, location(Ip(vertex.s)), depth)
        elseif typeof(vertex) == Mail
            tmp_node = thread_node("", vertex.s, Dict(), tmp_neighbours, Dict(), depth)
        elseif typeof(vertex) == Hash
            tmp_node = thread_node(vertex.s, "", Dict(), tmp_neighbours, Dict(), depth)
        end
        main_dict[vertex.s] = tmp_node
    end

    # store to json file
    open("$(root_server.s).json", "w") do f
		JSON.print(f, main_dict, 4)
	end
end

function extract_neighbours(tcMessage::Dict, depth::Int)
    global main_queue
    global main_visited_vertexes
    neighbours_arr = []
    if haskey(tcMessage, "resolutions")
        res_dict = tcMessage["resolutions"]
        for neighbour in res_dict
            if haskey(neighbour, "ip_address")
                ip_address = Ip(neighbour["ip_address"])
                if ip_address.s != "-"
                    append!(neighbours_arr, [ip_address])
                    if !(ip_address in main_visited_vertexes)
                        enqueue!(main_queue, [ip_address, depth+1])
                        append!(main_visited_vertexes, [ip_address])
                    end
                end
            end
            if haskey(neighbour, "domain")
                domain = Domain(neighbour["domain"])
                append!(neighbours_arr, [domain])
                if !(domain in main_visited_vertexes)
                    enqueue!(main_queue, [domain, depth+1])
                    append!(main_visited_vertexes, [domain])
                end
            end
        end
    end
    if haskey(tcMessage, "emails")
        emails = tcMessage["emails"]
        for email in emails
            email = Mail(email)
            if length(email.s) > 0
                append!(neighbours_arr, [email])
                if !(email in main_visited_vertexes)
                    enqueue!(main_queue, [email, depth+1])
                    append!(main_visited_vertexes, [email])
                end
            end
        end
    end
    if haskey(tcMessage, "subdomains")
        subdomains = tcMessage["subdomains"]
        for subdomain in subdomains
            if length(subdomain) > 0
                subdomain = Domain(subdomain)
                append!(neighbours_arr, [subdomain])
                if !(subdomain in main_visited_vertexes)
                    enqueue!(main_queue, [subdomain, depth+1])
                    append!(main_visited_vertexes, [subdomain])
                end
            end
        end
    end
    if haskey(tcMessage, "hashes")
        hashes = tcMessage["hashes"]
        for hash in hashes
            if length(hash) > 0
                hash = Hash(hash)
                append!(neighbours_arr, [hash])
                if !(hash in main_visited_vertexes)
                    enqueue!(main_queue, [hash, depth+1])
                    append!(main_visited_vertexes, [hash])
                end
            end
        end
    end
    if haskey(tcMessage, "domains")
        domains = tcMessage["domains"]
        for domain in domains
            domain = Domain(domain)
            append!(neighbours_arr, [domain])
            if !(domain in main_visited_vertexes)
                enqueue!(main_queue, [domain, depth+1])
                append!(main_visited_vertexes, [domain])
            end
        end
    end
    return neighbours_arr
end
