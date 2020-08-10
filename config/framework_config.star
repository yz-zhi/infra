#!/usr/bin/env lucicfg
# Copyright 2019 The Flutter Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""
Configurations for the framework repository.

The schedulers pull commits indirectly from GoB repo (https://chromium.googlesource.com/external/github.com/flutter/flutter)
which is mirrored from https://github.com/flutter/flutter.
"""

load("//lib/common.star", "common")
load("//lib/repos.star", "repos")

def _setup(branches):
    platfrom_args = {
        "linux": {
            "properties": {
                "shard": "framework_tests",
            },
        },
        "mac": {
            "properties": {
                "shard": "framework_tests",
                "cocoapods_version": "1.6.0",
            },
            "caches": [swarming.cache(name = "flutter_cocoapods", path = "cocoapods")],
        },
        "windows": {
            "properties": {
                "shard": "framework_tests",
            },
        },
    }

    for branch in branches:
        framework_prod_config(
            platfrom_args,
            branch,
            branches[branch]["version"],
            branches[branch]["testing-ref"],
        )

    framework_try_config(platfrom_args)

def framework_prod_config(platform_args, branch, version, ref):
    """Prod configurations for the framework repository.

    Args:
      platform_args(dict): Dictionary with default properties with platform as
        key.
      branch(str): The branch name we are creating configurations for.
      version(str): One of dev|beta|stable.
      ref(str): The git ref we are creating configurations for.
    """

    # TODO(godofredoc): Merge the recipe names once we remove the old one.
    recipe_name = ("flutter_" + version if version else "flutter")
    new_recipe_name = ("flutter/flutter_" + version if version else "flutter/flutter")
    drone_recipe_name = ("flutter/flutter_drone_" + version if version else "flutter/flutter_drone")
    luci.recipe(
        name = recipe_name,
        cipd_package = "flutter/recipe_bundles/flutter.googlesource.com/recipes",
        cipd_version = "refs/heads/master",
    )
    luci.recipe(
        name = "flutter/flutter_drone",
        cipd_package = "flutter/recipe_bundles/flutter.googlesource.com/recipes",
        cipd_version = "refs/heads/master",
    )
    luci.recipe(
        name = new_recipe_name,
        cipd_package = "flutter/recipe_bundles/flutter.googlesource.com/recipes",
        cipd_version = "refs/heads/master",
    )
    luci.recipe(
        name = drone_recipe_name,
        cipd_package = "flutter/recipe_bundles/flutter.googlesource.com/recipes",
        cipd_version = "refs/heads/master",
    )

    # Defines console views for prod builders
    console_view_name = ("framework" if branch == "master" else "%s_framework" % branch)
    luci.console_view(
        name = console_view_name,
        repo = repos.FLUTTER,
        refs = [ref],
    )

    # Defines prod schedulers
    trigger_name = branch + "-gitiles-trigger-framework"
    luci.gitiles_poller(
        name = trigger_name,
        bucket = "prod",
        repo = repos.FLUTTER,
        refs = [ref],
    )

    # Defines triggering policy
    if branch == "master":
        triggering_policy = scheduler.greedy_batching(
            max_concurrent_invocations = 6,
        )
    else:
        triggering_policy = scheduler.greedy_batching(
            max_batch_size = 1,
            max_concurrent_invocations = 3,
        )

    # Defines framework prod builders
    common.linux_prod_builder(
        name = "Linux%s|frwk" % ("" if branch == "master" else " " + branch),
        recipe = recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        **platform_args["linux"]
    )
    common.linux_prod_builder(
        name = "Linux%s build_tests|bld_tests" % ("" if branch == "master" else " " + branch),
        recipe = new_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "shard": "build_tests",
            "android_sdk_license": "\n24333f8a63b6825ea9c5514f83c2829b004d1fee",
            "android_sdk_preview_license": "\n84831b9409646a918e30573bab4c9c91346d8abd",
            "dependencies": ["android_sdk", "chrome_and_drivers"],
            "subshards": ["0", "1_last"],
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_prod_builder(
        name = "Linux%s framework_tests|frwk_tests" % ("" if branch == "master" else " " + branch),
        recipe = new_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "shard": "framework_tests",
            "android_sdk_license": "\n24333f8a63b6825ea9c5514f83c2829b004d1fee",
            "android_sdk_preview_license": "\n84831b9409646a918e30573bab4c9c91346d8abd",
            "dependencies": ["android_sdk", "chrome_and_drivers"],
            "subshards": ["libraries", "misc", "widgets"],
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_prod_builder(
        name = "Linux%s hostonly_devicelab_tests|hst_tests" % ("" if branch == "master" else " " + branch),
        recipe = new_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "shard": "hostonly_devicelab_tests",
            "android_sdk_license": "\n24333f8a63b6825ea9c5514f83c2829b004d1fee",
            "android_sdk_preview_license": "\n84831b9409646a918e30573bab4c9c91346d8abd",
            "dependencies": ["android_sdk", "chrome_and_drivers"],
            "subshards": ["0", "1", "2", "3_last"],
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_prod_builder(
        name = "Linux%s tool_tests|tool_tests" % ("" if branch == "master" else " " + branch),
        recipe = new_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "shard": "tool_tests",
            "android_sdk_license": "\n24333f8a63b6825ea9c5514f83c2829b004d1fee",
            "android_sdk_preview_license": "\n84831b9409646a918e30573bab4c9c91346d8abd",
            "dependencies": ["android_sdk", "chrome_and_drivers"],
            "subshards": ["general", "commands", "integration"],
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_prod_builder(
        name = "Linux%s web_tests|web_tests" % ("" if branch == "master" else " " + branch),
        recipe = new_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "shard": "web_tests",
            "android_sdk_license": "\n24333f8a63b6825ea9c5514f83c2829b004d1fee",
            "android_sdk_preview_license": "\n84831b9409646a918e30573bab4c9c91346d8abd",
            "dependencies": ["android_sdk", "chrome_and_drivers"],
            "subshards": ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11_last"],
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_prod_builder(
        name = "Linux%s SDK Drone|frwdrn" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = None,
        no_notify = True,
        priority = 30 if branch == "master" else 25,
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_prod_builder(
        name = "Mac%s|frwk" % ("" if branch == "master" else " " + branch),
        recipe = recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        **platform_args["mac"]
    )
    common.windows_prod_builder(
        name = "Windows%s|frwk" % ("" if branch == "master" else " " + branch),
        recipe = recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        **platform_args["windows"]
    )

def framework_try_config(platform_args):
    """Try configurations for the framework repository.

    Args:
      platform_args(dict): Dictionary with default properties with platform as
        key.
    """

    # Defines a list view for try builders
    list_view_name = "framework-try"
    luci.list_view(
        name = "framework-try",
        title = "Framework try builders",
    )

    # Defines framework try builders
    common.linux_try_builder(
        name = "Linux|frwk",
        recipe = "flutter",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        add_cq = True,
        **platform_args["linux"]
    )
    common.linux_try_builder(
        name = "Linux build_tests|bld_tests",
        recipe = "flutter/flutter",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "shard": "build_tests",
            "android_sdk_license": "\n24333f8a63b6825ea9c5514f83c2829b004d1fee",
            "android_sdk_preview_license": "\n84831b9409646a918e30573bab4c9c91346d8abd",
            "dependencies": ["android_sdk", "chrome_and_drivers"],
            "subshards": ["0", "1_last"],
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_try_builder(
        name = "Linux framework_tests|frwk_tests",
        recipe = "flutter/flutter",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "shard": "framework_tests",
            "android_sdk_license": "\n24333f8a63b6825ea9c5514f83c2829b004d1fee",
            "android_sdk_preview_license": "\n84831b9409646a918e30573bab4c9c91346d8abd",
            "dependencies": ["android_sdk", "chrome_and_drivers"],
            "subshards": ["libraries", "misc", "widgets"],
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_try_builder(
        name = "Linux hostonly_devicelab_tests|hst_tests",
        recipe = "flutter/flutter",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "shard": "hostonly_devicelab_tests",
            "android_sdk_license": "\n24333f8a63b6825ea9c5514f83c2829b004d1fee",
            "android_sdk_preview_license": "\n84831b9409646a918e30573bab4c9c91346d8abd",
            "dependencies": ["android_sdk", "chrome_and_drivers"],
            "subshards": ["0", "1", "2", "3_last"],
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_try_builder(
        name = "Linux tool_tests|tool_tests",
        recipe = "flutter/flutter",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "shard": "tool_tests",
            "android_sdk_license": "\n24333f8a63b6825ea9c5514f83c2829b004d1fee",
            "android_sdk_preview_license": "\n84831b9409646a918e30573bab4c9c91346d8abd",
            "dependencies": ["android_sdk", "chrome_and_drivers"],
            "subshards": ["general", "commands", "integration"],
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_try_builder(
        name = "Linux web_tests|web_tests",
        recipe = "flutter/flutter",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "shard": "web_tests",
            "android_sdk_license": "\n24333f8a63b6825ea9c5514f83c2829b004d1fee",
            "android_sdk_preview_license": "\n84831b9409646a918e30573bab4c9c91346d8abd",
            "dependencies": ["android_sdk", "chrome_and_drivers"],
            "subshards": ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11_last"],
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_try_builder(
        name = "Linux SDK Drone|frwkdrn",
        recipe = "flutter/flutter_drone",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_try_builder(
        name = "Mac|frwk",
        recipe = "flutter",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        **platform_args["mac"]
    )
    common.windows_try_builder(
        name = "Windows|frwk",
        recipe = "flutter",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        **platform_args["windows"]
    )

framework_config = struct(setup = _setup)
