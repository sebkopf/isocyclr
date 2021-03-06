

#' plot reaction diagram
#'
#' @param y_data data frame with component and y columns to be used for plotting. If missing, arranges diagram like reaction scheme.
#' @param arrows whether to generate arrows for reaction diagram
#' @export
generate_reaction_diagram <- function(ip, y_data = NULL, add_arrows = FALSE) {
  if (!is(ip, "isopath")) stop ("can only generate diagram for isopath", call. = FALSE)

  if (length(ip$reactions) == 0 || length(ip$components) == 0)
    stop("need at least two components and one reaction in order to plot the reaction diagram", call. = FALSE)

  # TODO: extract the prepping of a reaction diagramm data frame into a separate function
  # determin x locations for components
  general_x <-
    # combine compnentes and isotopes
    left_join(
      ip %>% get_component_matrix() %>%
        gather(isotope, iso_stoic, -component, -variable),
      ip %>% get_reaction_matrix() %>%
        gather(component, comp_stoic, -reaction, -abscissa, -flux),
      by = "component"
    ) %>%
    # make sure to remove empty entries
    filter(!is.na(iso_stoic), !is.na(comp_stoic)) %>%
    # calculate abscissa for each component
    mutate(x = abscissa - ifelse(comp_stoic < 0, 1, 0 ))

  # determine y locations for components
  if (is.null(y_data)) {
    components_xy <-
      general_x %>%
      select(isotope, component, variable, x) %>%
      distinct() %>% arrange(desc(component)) %>%
      group_by(isotope, x) %>%
      mutate(y = seq(-length(x)+1, length(x)-1, length.out = length(x))) %>%
      ungroup()
  } else {
    components_xy <-
      left_join(
        general_x %>% select(isotope, component, variable, x) %>% distinct(),
        y_data,
        by = "component"
      ) %>%
      filter(!is.na(y))
  }

  # grouping parameters (relevant if data_y provided):
  grouping <- setdiff(names(components_xy), c("isotope", "component", "variable", "x", "y"))

  # rxn components (+horizontal alignment)
  rxn_components_xy <-
    left_join(
      general_x %>% select(reaction, component, isotope, comp_stoic, x),
      components_xy,
      by = c("component", "isotope", "x")) %>%
    filter(!is.na(y)) %>%
    # move reaction components horizontally to largest x (i.e. the last occurence of a component)
    group_by(component) %>%
    mutate(max_x = max(x)) %>%
    ungroup() %>%
    group_by(!!!purrr::map(grouping, rlang::sym), component, isotope) %>%
    mutate(y = y[x == max_x][1], x = max_x) %>%
    ungroup()

  # arrow location (% along the line)
  location <- 0.65

  ## FIXME:
  ## need to implement way to do the x alignment properly for reverse reactions
  ## approach: do x adjustment BEFORE y calculation BUT for y calculation take
  ## into consideration not just the ys on the current x but all arrows that are
  ## either ending or reaching past this interval and use that as the # of ys
  ## - additionally, for the y calculation, consider looping through x from left
  ## to right and using the arrow origins on the left as the average y to start the
  ## new y stack from
  ## - additionally, do proper y offset for parallel arrows in opposite direction
  ## - additionally, sort y stack by the order the user has added the componente
  ## (not just alphabetically blind)

  # reaction lines (offset for parallel reaction lines)
  rxns_xy <-
    inner_join(
      rxn_components_xy %>% filter(comp_stoic > 0) %>% rename(xstart = x, ystart = y),
      rxn_components_xy %>% filter(comp_stoic < 0) %>% rename(xend = x, yend = y),
      by = c("reaction", "isotope", grouping)
    ) %>%
    # inverted x and y to also align reverse reactions
    mutate(
      xstart_grp = ifelse(xstart > xend, xend, xstart),
      xend_grp = ifelse(xstart > xend, xstart, xend),
      ystart_grp = ifelse(ystart > yend, yend, ystart),
      yend_grp = ifelse(ystart > yend, ystart, yend)
    ) %>%
    # offset for parallel lines
    group_by(isotope, xstart_grp, ystart_grp, xend_grp, yend_grp) %>%
    arrange(reaction) %>%
    # offset in y direction depending on multi-line reactions
    mutate(
      y_scale = max(c(ystart, yend)) - min(c(ystart, yend)),
      y_offset = 0.02 * (y_scale + 1) * seq(-n()+1, n()-1, length.out = n())) %>%
    ungroup() %>%
    mutate(
      ystart = ystart + y_offset,
      yend = yend + y_offset
    ) %>%
    # arrows
    group_by(isotope, reaction, component.x, component.y) %>%
    mutate(
      xarrow = xend + (xstart - xend) * location,
      yarrow = yend + (ystart - yend) * location
    )

  # theme
  plot_theme <- theme(
    panel.grid.major = element_blank(),
    panel.grid.minor = element_blank(),
    axis.text.x = element_blank(),
    axis.ticks.x = element_blank(),
    legend.box = "vertical"
  )

  if (is.null(y_data)) {
    plot_theme <- plot_theme +
      theme(
        axis.text.y = element_blank(),
        axis.ticks.y = element_blank()
      )
  }

  # plot everything
  p <- ggplot()

  if (add_arrows) {
    p <- p +
      geom_segment(
        data = rxns_xy, size = 1.5,
        map = aes(x=xarrow, y=yarrow,
                  xend=xstart, yend=ystart,
                  color = reaction)) +

      geom_segment(
        data = rxns_xy, size = 1.5,
        arrow = arrow(length = unit(0.05, "npc")),
        map = aes(x=xend, y=yend,
                  xend=xarrow, yend=yarrow,
                  color = reaction))
  } else {
    p <- p +
      geom_segment(
        data = rxns_xy, size = 1.5,
        map = aes(x=xend, y=yend,
                  xend=xstart, yend=ystart,
                  color = reaction))
  }

  p +
    geom_label(
      data = rxn_components_xy %>% select(!!!grouping, component, isotope, x, y, variable) %>% unique(),
      hjust = 0.5, label.padding = unit(0.6, "lines"),
      map = aes(x, y, label = component,
                fill = ifelse(variable, "variable", "fixed"))) +
    facet_grid(isotope~.) +
    theme_bw() + plot_theme +
    scale_fill_manual("Components:", values = c("grey50", "grey90")) +
    scale_x_continuous("", expand = c(0, 0.5)) +
    scale_y_continuous("", expand = c(0, 0.5)) +
    labs(color = "Reactions:")
}
