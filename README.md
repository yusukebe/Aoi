Aoi
====

Simple web application for sharing Markdown plain texts within team members. Using an ElasticSearch as a back-end.

## Description

There are some tools for the development of software. GitHub is one of the best repository and source code management service. But I found that we don't have the simple documentation tool for **STOCK** plain texts. Such a Markdown texts on Gist or Slack are easy way to share the documents with team mates **at the memonet** . So, these docs are not have good findability. **Aoi** is very simple, one application is only for the specific members, Markdown rendering and preview support, and easy to search stocked texts.

## Screenshot

Web can see text summaries like time-line based application.

![list](https://cloud.githubusercontent.com/assets/10682/8519166/9cf63954-240b-11e5-8a7d-89f9247fe08d.png)

GitHub flavor Markdown rendering.

![show](https://cloud.githubusercontent.com/assets/10682/8519158/892f91f4-240b-11e5-8e77-6db626119832.png)

Easy to write, preview, edit, and delete.

![edit](https://cloud.githubusercontent.com/assets/10682/8519191/cdf77a22-240b-11e5-9b37-3d3c547458a9.png)

## Requirement

* Ruby
* Sinatra
* Other gem libraries
* ElasticSearch

## Usage

1. Setup configuration file
2. Run the ElasticSearch
3. Run the Aoi Web app
4. And then, you can login with GitHub account

## Install

## Licence

[MIT](https://github.com/tcnksm/tool/blob/master/LICENCE)

## Author

[Yusuke Wada a.k.a. yusukebe](https://github.com/yusukebe)
