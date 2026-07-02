local ls = require "luasnip"
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

return {
  s("ans-play", {
    t { "---", "- name: " },
    i(1, "Deploy app"),
    t { "", "  hosts: " },
    i(2, "all"),
    t { "", "  become: ", "  tasks:", "    - name: " },
    i(3, "Install package"),
    t { "", "      " },
    i(4, "apt"),
    t { ":", "        name: " },
    i(5, "nginx"),
    t { "", "        state: present", "" },
  }),

  s("ans-task", {
    t { "- name: " },
    i(1, "Do something"),
    t { "", "  " },
    i(2, "ansible.builtin.debug"),
    t { ":", "    msg: " },
    i(3, "Hello World"),
    t { "", "" },
  }),

  s("ans-inventory", {
    t {
      "---",
      "all:",
      "  children:",
      "    ",
    },
    i(1, "web"),
    t { ":", "      hosts:", "        " },
    i(2, "server-01"),
    t { ":", "          ansible_host: " },
    i(3, "192.168.1.10"),
    t { "", "          ansible_user: " },
    i(4, "root"),
    t { "", "          ansible_ssh_private_key_file: " },
    i(5, "~/.ssh/id_rsa"),
  }),

  s("ans-template", {
    t { "- name: " },
    i(1, "Render template"),
    t { "", "  ansible.builtin.template:", "    src: " },
    i(2, "app.conf.j2"),
    t { "", "    dest: " },
    i(3, "/etc/app/app.conf"),
    t { "", "    owner: " },
    i(4, "root"),
    t { "", "    group: " },
    i(5, "root"),
    t { "", "    mode: '0644'", "" },
  }),
}
