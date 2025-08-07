
import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
import * as d3 from "d3"

// D3.js Transaction Graph Hook
let Hooks = {}

Hooks.TransactionGraph = {
  mounted() {
    this.initGraph()
    this.handleEvent("update_graph", (data) => {
      this.updateGraph(data.data)
    })
  },

  initGraph() {
    const container = this.el
    const width = container.clientWidth
    const height = container.clientHeight

    // Clear any existing content
    d3.select(container).selectAll("*").remove()

    // Create SVG
    this.svg = d3.select(container)
      .append("svg")
      .attr("width", width)
      .attr("height", height)

    // Create group for zoom/pan
    this.g = this.svg.append("g")

    // Add zoom behavior
    const zoom = d3.zoom()
      .scaleExtent([0.1, 4])
      .on("zoom", (event) => {
        this.g.attr("transform", event.transform)
      })

    this.svg.call(zoom)

    // Create simulation
    this.simulation = d3.forceSimulation()
      .force("link", d3.forceLink().id(d => d.id).distance(100))
      .force("charge", d3.forceManyBody().strength(-300))
      .force("center", d3.forceCenter(width / 2, height / 2))
      .force("collision", d3.forceCollide().radius(30))
  },

  updateGraph(data) {
    if (!data || !data.nodes || !data.links) return

    const { nodes, links } = data

    // Color scale for different node types
    const color = d3.scaleOrdinal()
      .domain(["transaction", "input", "output"])
      .range(["#ff6b6b", "#4ecdc4", "#45b7d1"])

    // Update links
    const link = this.g.selectAll(".link")
      .data(links)
      .join("line")
      .classed("link", true)
      .attr("stroke", "#999")
      .attr("stroke-opacity", 0.8)
      .attr("stroke-width", 2)

    // Update nodes
    const node = this.g.selectAll(".node")
      .data(nodes)
      .join("g")
      .classed("node", true)
      .call(d3.drag()
        .on("start", (event, d) => {
          if (!event.active) this.simulation.alphaTarget(0.3).restart()
          d.fx = d.x
          d.fy = d.y
        })
        .on("drag", (event, d) => {
          d.fx = event.x
          d.fy = event.y
        })
        .on("end", (event, d) => {
          if (!event.active) this.simulation.alphaTarget(0)
          d.fx = null
          d.fy = null
        }))

    // Add circles to nodes
    node.selectAll("circle").remove()
    node.append("circle")
      .attr("r", d => d.type === "transaction" ? 20 : 15)
      .attr("fill", d => color(d.type))
      .attr("stroke", "#fff")
      .attr("stroke-width", 2)

    // Add labels to nodes
    node.selectAll("text").remove()
    node.append("text")
      .text(d => {
        switch (d.type) {
          case "transaction":
            return "TX"
          case "input":
            return `In ${d.index}`
          case "output":
            return `Out ${d.index}`
          default:
            return ""
        }
      })
      .attr("text-anchor", "middle")
      .attr("dy", "0.35em")
      .attr("font-size", "10px")
      .attr("fill", "white")
      .attr("font-weight", "bold")

    // Add tooltips
    node.append("title")
      .text(d => {
        switch (d.type) {
          case "transaction":
            return `Transaction: ${d.txid}`
          case "input":
            return `Input ${d.index}\nPrevious: ${d.txid}:${d.vout}`
          case "output":
            return `Output ${d.index}\nValue: ${d.value || 'N/A'}\nAddress: ${d.address || 'N/A'}`
          default:
            return ""
        }
      })

    // Update simulation
    this.simulation.nodes(nodes)
    this.simulation.force("link").links(links)
    this.simulation.alpha(1).restart()

    // Update positions on tick
    this.simulation.on("tick", () => {
      link
        .attr("x1", d => d.source.x)
        .attr("y1", d => d.source.y)
        .attr("x2", d => d.target.x)
        .attr("y2", d => d.target.y)

      node.attr("transform", d => `translate(${d.x},${d.y})`)
    })
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket
